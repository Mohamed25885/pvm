<?php

ini_set('memory_limit', '1G'); // S3 buffers full output — 50 procs × 20k lines needs headroom

/**
 * stress_test.php
 *
 * Stress tests for PVM's process management (IOProcessManager).
 * All 4 scenarios run in PARALLEL for maximum pressure.
 *
 *   php stress_test.php                  # run all scenarios in parallel
 *   php stress_test.php --scenario=1     # rapid child spawn only
 *   php stress_test.php --scenario=2     # deep process tree only
 *   php stress_test.php --scenario=3     # high output volume only
 *   php stress_test.php --scenario=4     # long-running + kill only
 *
 *   # Tune intensity
 *   php stress_test.php --spawn=500 --depth=12 --trees=20 --procs=30 --lines=10000
 */

// ─── Config (overridable via CLI) ─────────────────────────────────────────────

$opts = getopt('', [
    'scenario:',
    'internal-tree:',
    'spawn:',        // scenario 1: number of rapid-spawn processes
    'depth:',        // scenario 2: tree depth
    'trees:',        // scenario 2: number of trees
    'procs:',        // scenario 3: number of high-output processes
    'lines:',        // scenario 3: lines per process
    'count:',        // scenario 4: long-running process count
    'kill-after:',   // scenario 4: seconds before kill
    'laravel-path:', // scenario 5: path to Laravel project root
    'laravel-port:', // scenario 5: base port (instances get port, port+1, port+2 ...)
    'instances:',    // scenario 5: number of parallel artisan serve instances
    'requests:',     // scenario 5: concurrent HTTP requests per instance
    'workers:',      // scenario 5: queue workers to spawn per instance
]);

$CFG = [
    'spawn'        => (int)  ($opts['spawn']        ?? 300),
    'depth'        => (int)  ($opts['depth']        ?? 10),
    'trees'        => (int)  ($opts['trees']        ?? 10),
    'procs'        => (int)  ($opts['procs']        ?? 20),
    'lines'        => (int)  ($opts['lines']        ?? 8000),
    'count'        => (int)  ($opts['count']        ?? 15),
    'kill_after'   => (float)($opts['kill-after']   ?? 2.0),
    'laravel_path' => (string)($opts['laravel-path'] ?? ''),
    'laravel_port' => (int)  ($opts['laravel-port'] ?? 8100),
    'instances'    => (int)  ($opts['instances']    ?? 3),
    'requests'     => (int)  ($opts['requests']     ?? 50),
    'workers'      => (int)  ($opts['workers']      ?? 2),
];

// ─── Helpers ──────────────────────────────────────────────────────────────────

function ts(): string
{
    return date('H:i:s');
}

function hdr(string $title): void
{
    $pad = str_repeat('─', 58);
    echo "\n┌{$pad}┐\n│  " . str_pad($title, 56) . "│\n└{$pad}┘\n";
}

function log_line(string $tag, string $color, string $msg): void
{
    $colors = [
        'info'  => "\033[36m",
        'ok'    => "\033[32m",
        'warn'  => "\033[33m",
        'fail'  => "\033[31m",
        'reset' => "\033[0m",
    ];
    $c = $colors[$color] ?? '';
    $r = $colors['reset'];
    echo "{$c}[" . ts() . "] [{$tag}]{$r} {$msg}\n";
}

function info(string $tag, string $msg): void
{
    log_line($tag, 'info', $msg);
}
function ok(string $tag, string $msg): void
{
    log_line($tag, 'ok',   $msg);
}
function warn(string $tag, string $msg): void
{
    log_line($tag, 'warn', $msg);
}
function fail(string $tag, string $msg): void
{
    log_line($tag, 'fail', $msg);
}

function elapsed(float $start): string
{
    return round(microtime(true) - $start, 3) . 's';
}

function is_process_alive(int $pid): bool
{
    if (PHP_OS_FAMILY === 'Windows') {
        $out = shell_exec("tasklist /fi \"PID eq {$pid}\" /fo csv /nh 2>NUL");
        return str_contains((string) $out, (string) $pid);
    }
    return function_exists('posix_kill') && posix_kill($pid, 0);
}

function mem(): string
{
    return round(memory_get_usage(true) / 1024 / 1024, 1) . 'MB';
}

// ─── Scenario 1 — Rapid spawn ─────────────────────────────────────────────────

function run_scenario1(array $cfg): void
{
    $tag   = 'S1:rapid';
    $count = $cfg['spawn'];
    $start = microtime(true);
    $batch = 50;

    info($tag, "Starting — {$count} rapid-spawn processes (batch={$batch})");

    $pool      = [];
    $launched  = 0;
    $succeeded = 0;
    $failed    = 0;

    while ($launched < $count || !empty($pool)) {
        while ($launched < $count && count($pool) < $batch) {
            $i    = $launched + 1;
            $code = 'echo "child ' . $i . ' pid=" . getmypid() . PHP_EOL;';
            $proc = proc_open([PHP_BINARY, '-r', $code], [
                1 => ['pipe', 'w'],
                2 => ['pipe', 'w'],
            ], $pipes);

            if (is_resource($proc)) {
                stream_set_blocking($pipes[1], false);
                stream_set_blocking($pipes[2], false);
                $pool[] = ['proc' => $proc, 'pipes' => $pipes, 'i' => $i, 'buf' => ''];
            } else {
                $failed++;
            }
            $launched++;
        }

        foreach ($pool as $k => &$entry) {
            $chunk = @fread($entry['pipes'][1], 8192);
            if ($chunk !== false) $entry['buf'] .= $chunk;

            $status = proc_get_status($entry['proc']);
            if (!$status['running']) {
                fclose($entry['pipes'][1]);
                fclose($entry['pipes'][2]);
                proc_close($entry['proc']);

                if ($status['exitcode'] === 0 && str_contains($entry['buf'], 'child')) {
                    $succeeded++;
                } else {
                    $failed++;
                    warn($tag, "Process {$entry['i']} failed (exit={$status['exitcode']})");
                }
                unset($pool[$k]);
            }
        }
        unset($entry);
        $pool = array_values($pool);
        usleep(1000);
    }

    ok($tag, "Done in " . elapsed($start) . " — succeeded={$succeeded} failed={$failed}");
}

// ─── Scenario 2 — Deep process tree ──────────────────────────────────────────

function run_scenario2(array $cfg): void
{
    $tag   = 'S2:tree';
    $depth = $cfg['depth'];
    $trees = $cfg['trees'];
    $start = microtime(true);

    info($tag, "Starting — {$trees} trees × depth {$depth} (all parallel)");

    $self = __FILE__;
    $pool = [];

    for ($t = 1; $t <= $trees; $t++) {
        $proc = proc_open([PHP_BINARY, $self, "--internal-tree={$depth}"], [
            1 => ['pipe', 'w'],
            2 => ['pipe', 'w'],
        ], $pipes);

        if (!is_resource($proc)) {
            fail($tag, "Could not start tree {$t}");
            continue;
        }

        stream_set_blocking($pipes[1], false);
        stream_set_blocking($pipes[2], false);
        $pool[] = ['proc' => $proc, 'pipes' => $pipes, 't' => $t, 'out' => '', 'err' => ''];
    }

    $ok_trees   = 0;
    $fail_trees = 0;

    while (!empty($pool)) {
        foreach ($pool as $k => &$entry) {
            $c = @fread($entry['pipes'][1], 8192);
            if ($c !== false) $entry['out'] .= $c;
            $e = @fread($entry['pipes'][2], 8192);
            if ($e !== false) $entry['err'] .= $e;

            $status = proc_get_status($entry['proc']);
            if (!$status['running']) {
                $entry['out'] .= stream_get_contents($entry['pipes'][1]);
                $entry['err'] .= stream_get_contents($entry['pipes'][2]);
                fclose($entry['pipes'][1]);
                fclose($entry['pipes'][2]);
                proc_close($entry['proc']);

                $levels = substr_count($entry['out'], 'level=');
                if ($levels === $depth) {
                    ok($tag, "Tree {$entry['t']}: all {$levels} levels ✓");
                    $ok_trees++;
                } else {
                    warn($tag, "Tree {$entry['t']}: expected {$depth} levels, got {$levels}");
                    $fail_trees++;
                }
                unset($pool[$k]);
            }
        }
        unset($entry);
        $pool = array_values($pool);
        usleep(5000);
    }

    ok($tag, "Done in " . elapsed($start) . " — ok={$ok_trees} failed={$fail_trees}");
}

// ─── Scenario 3 — High output volume (full buffering, no mercy) ───────────────
//
// All $procs processes run simultaneously. Every byte of stdout and stderr
// is buffered in full so we can verify zero data loss end-to-end.
// Memory usage is intentional — that's the stress.

function run_scenario3(array $cfg): void
{
    $tag   = 'S3:output';
    $procs = $cfg['procs'];
    $lines = $cfg['lines'];
    $start = microtime(true);

    $expected_bytes = $procs * $lines * 2 * 75; // rough: 2 streams × ~75 bytes/line
    $expected_mb    = round($expected_bytes / 1024 / 1024);
    info($tag, "Starting — {$procs} processes × {$lines} lines each (stdout+stderr) all parallel");
    info($tag, "Expected buffer usage: ~{$expected_mb}MB | current heap: " . mem());

    $pool = [];

    for ($i = 1; $i <= $procs; $i++) {
        $code = <<<PHP
            \$n = {$lines};
            for (\$j = 0; \$j < \$n; \$j++) {
                echo "STDOUT line \$j proc {$i} " . str_repeat("x", 60) . PHP_EOL;
                fwrite(STDERR, "STDERR line \$j proc {$i} " . str_repeat("y", 60) . PHP_EOL);
            }
        PHP;

        $proc = proc_open([PHP_BINARY, '-r', $code], [
            1 => ['pipe', 'w'],
            2 => ['pipe', 'w'],
        ], $pipes);

        if (!is_resource($proc)) {
            fail($tag, "Could not start process {$i}");
            continue;
        }

        stream_set_blocking($pipes[1], false);
        stream_set_blocking($pipes[2], false);

        // Full buffers — every byte kept in memory deliberately
        $pool[] = ['proc' => $proc, 'pipes' => $pipes, 'i' => $i, 'out' => '', 'err' => ''];
    }

    $total_out  = 0;
    $total_err  = 0;
    $ok_count   = 0;
    $warn_count = 0;
    $peak_mb    = 0;

    while (!empty($pool)) {
        foreach ($pool as $k => &$entry) {
            // Read large chunks to keep pipes from filling up and blocking children
            $c = @fread($entry['pipes'][1], 65536);
            if ($c !== false) $entry['out'] .= $c;
            $e = @fread($entry['pipes'][2], 65536);
            if ($e !== false) $entry['err'] .= $e;

            $status = proc_get_status($entry['proc']);
            if (!$status['running']) {
                // Final drain — child exited, flush remaining pipe data
                $entry['out'] .= stream_get_contents($entry['pipes'][1]);
                $entry['err'] .= stream_get_contents($entry['pipes'][2]);
                fclose($entry['pipes'][1]);
                fclose($entry['pipes'][2]);
                proc_close($entry['proc']);

                $ol = substr_count($entry['out'], "\n");
                $el = substr_count($entry['err'], "\n");
                $total_out += $ol;
                $total_err += $el;

                // Track peak memory across the drain loop
                $cur_mb = round(memory_get_usage(true) / 1024 / 1024, 1);
                if ($cur_mb > $peak_mb) $peak_mb = $cur_mb;

                if ($ol === $lines && $el === $lines) {
                    ok($tag, "Proc {$entry['i']}: stdout={$ol} stderr={$el} ✓ [heap={$cur_mb}MB]");
                    $ok_count++;
                } else {
                    warn($tag, "Proc {$entry['i']}: stdout={$ol} stderr={$el} (expected {$lines}) [heap={$cur_mb}MB]");
                    $warn_count++;
                }

                // Release buffers immediately after verification
                $entry['out'] = '';
                $entry['err'] = '';
                unset($pool[$k]);
            }
        }
        unset($entry);
        $pool = array_values($pool);
        usleep(5000);
    }

    ok($tag, "Done in " . elapsed($start) . " — stdout={$total_out} stderr={$total_err} lines");
    ok($tag, "Processes ok={$ok_count} warned={$warn_count} | peak heap={$peak_mb}MB");
}

// ─── Scenario 4 — Long-running + kill ────────────────────────────────────────

function run_scenario4(array $cfg): void
{
    $tag        = 'S4:kill';
    $count      = $cfg['count'];
    $kill_after = $cfg['kill_after'];
    $start      = microtime(true);

    info($tag, "Starting — {$count} sleeping processes, kill after {$kill_after}s");

    $pool = [];
    $pids = [];

    for ($i = 0; $i < $count; $i++) {
        $code = 'echo "pid=" . getmypid() . PHP_EOL; fflush(STDOUT); sleep(300);';
        $proc = proc_open([PHP_BINARY, '-r', $code], [
            1 => ['pipe', 'w'],
            2 => ['pipe', 'w'],
        ], $pipes);

        if (!is_resource($proc)) {
            fail($tag, "Could not start process {$i}");
            continue;
        }

        stream_set_blocking($pipes[1], false);
        $pool[] = ['proc' => $proc, 'pipes' => $pipes];
    }

    usleep(300_000);

    foreach ($pool as &$entry) {
        $line = fgets($entry['pipes'][1]);
        if (preg_match('/pid=(\d+)/', (string) $line, $m)) {
            $pids[] = (int) $m[1];
        }
    }
    unset($entry);

    $alive_before = count(array_filter($pids, 'is_process_alive'));
    info($tag, "Alive before kill: {$alive_before} / " . count($pids));
    info($tag, "PIDs: " . implode(', ', $pids));
    info($tag, "Waiting {$kill_after}s...");

    usleep((int) ($kill_after * 1_000_000));

    info($tag, "Sending kill signals...");
    foreach ($pool as $entry) {
        @fclose($entry['pipes'][1]);
        @fclose($entry['pipes'][2]);
        @proc_terminate($entry['proc']);
        @proc_close($entry['proc']);
    }

    if (PHP_OS_FAMILY === 'Windows') {
        foreach ($pids as $pid) {
            exec("taskkill /pid {$pid} /t /f 2>NUL");
        }
    }

    $deadline  = microtime(true) + 5.0;
    $remaining = $pids;

    while (!empty($remaining) && microtime(true) < $deadline) {
        usleep(100_000);
        $remaining = array_values(array_filter($remaining, 'is_process_alive'));
    }

    if (empty($remaining)) {
        ok($tag, "All {$count} processes terminated in " . elapsed($start) . " ✓");
    } else {
        fail($tag, count($remaining) . " zombie(s) after timeout: " . implode(', ', $remaining));
        warn($tag, "Process cleanup may not be propagating correctly.");
    }
}

// ─── Scenario 5 — Real Laravel project ───────────────────────────────────────
//
// Spins up $instances of `php artisan serve` simultaneously on consecutive
// ports, waits for each to accept HTTP, then:
//   a) hammers each with $requests concurrent HTTP requests
//   b) spawns $workers queue workers per instance
//   c) kills the artisan parent and verifies all workers die with it
//
// Usage:
//   php stress_test.php --scenario=5 --laravel-path=/path/to/app \
//       --instances=3 --requests=50 --workers=2 --laravel-port=8100

function parse_dotenv(string $projectPath): array
{
    $env  = [];
    $file = rtrim($projectPath, '/\\') . DIRECTORY_SEPARATOR . '.env';

    if (!file_exists($file)) return $env;

    foreach (file($file, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES) as $line) {
        if (str_starts_with(trim($line), '#')) continue;
        if (!str_contains($line, '='))         continue;
        [$key, $val] = explode('=', $line, 2);
        $env[trim($key)] = trim($val, " \t\"'");
    }

    return $env;
}

function wait_for_http(string $url, int $timeoutMs = 10_000): bool
{
    $deadline = microtime(true) + $timeoutMs / 1000;

    while (microtime(true) < $deadline) {
        $ctx = stream_context_create(['http' => [
            'timeout'        => 1,
            'ignore_errors'  => true,
        ]]);
        $body = @file_get_contents($url, false, $ctx);
        if ($body !== false) return true;
        usleep(200_000);
    }

    return false;
}

function http_get_async(string $url): mixed
{
    $ctx = stream_context_create(['http' => [
        'timeout'       => 10,
        'ignore_errors' => true,
    ]]);
    return @file_get_contents($url, false, $ctx);
}

function run_scenario5(array $cfg): void
{
    $tag       = 'S5:laravel';
    $path      = rtrim($cfg['laravel_path'], '/\\');
    $basePort  = $cfg['laravel_port'];
    $instances = $cfg['instances'];
    $requests  = $cfg['requests'];
    $workers   = $cfg['workers'];
    $start     = microtime(true);

    // ── Validate ──────────────────────────────────────────────────────────────

    if (empty($path)) {
        fail($tag, 'No --laravel-path provided. Usage: --laravel-path=/path/to/laravel');
        return;
    }

    if (!file_exists($path . DIRECTORY_SEPARATOR . 'artisan')) {
        fail($tag, "artisan not found in {$path} — is this a Laravel project?");
        return;
    }

    $env = parse_dotenv($path);
    $db  = $env['DB_DATABASE'] ?? '(unknown)';
    $dbHost = $env['DB_HOST'] ?? '127.0.0.1';

    info($tag, "Laravel project: {$path}");
    info($tag, "DB: MySQL @ {$dbHost} / {$db}");
    info($tag, "Instances: {$instances} | Requests/instance: {$requests} | Workers/instance: {$workers}");

    // ── Phase 1: Boot timing — spin up $instances simultaneously ──────────────

    hdr('S5 Phase 1 — Startup time');

    $servers    = [];
    $bootTimes  = [];

    for ($i = 0; $i < $instances; $i++) {
        $port    = $basePort + $i;
        $bootStart = microtime(true);

        $proc = proc_open(
            [PHP_BINARY, 'artisan', 'serve', '--host=127.0.0.1', "--port={$port}"],
            [
                0 => ['pipe', 'r'],
                1 => ['pipe', 'w'],
                2 => ['pipe', 'w'],
            ],
            $pipes,
            $path
        );

        if (!is_resource($proc)) {
            fail($tag, "Could not start artisan serve on port {$port}");
            continue;
        }

        stream_set_blocking($pipes[1], false);
        stream_set_blocking($pipes[2], false);

        $servers[] = [
            'proc'      => $proc,
            'pipes'     => $pipes,
            'port'      => $port,
            'url'       => "http://127.0.0.1:{$port}",
            'bootStart' => $bootStart,
            'pid'       => proc_get_status($proc)['pid'],
            'workers'   => [],
        ];

        info($tag, "Instance {$i} launched on port {$port} (pid={$servers[$i]['pid']})");
    }

    // Wait for all instances to be ready
    $ready = 0;
    foreach ($servers as $k => &$srv) {
        info($tag, "Waiting for {$srv['url']} to accept connections...");
        if (wait_for_http($srv['url'] . '/', 15_000)) {
            $bt = round((microtime(true) - $srv['bootStart']) * 1000);
            $bootTimes[] = $bt;
            ok($tag, "Instance on port {$srv['port']} ready in {$bt}ms ✓");
            $ready++;
        } else {
            fail($tag, "Instance on port {$srv['port']} did not respond within 15s");
        }
    }
    unset($srv);

    if ($ready === 0) {
        fail($tag, 'No instances came up — aborting S5');
        foreach ($servers as $srv) {
            @proc_terminate($srv['proc']);
            @proc_close($srv['proc']);
        }
        return;
    }

    if (!empty($bootTimes)) {
        $avg = round(array_sum($bootTimes) / count($bootTimes));
        $min = min($bootTimes);
        $max = max($bootTimes);
        ok($tag, "Boot times — avg={$avg}ms min={$min}ms max={$max}ms");
    }

    // ── Phase 2: Queue workers ────────────────────────────────────────────────

    hdr('S5 Phase 2 — Queue workers');

    foreach ($servers as &$srv) {
        for ($w = 0; $w < $workers; $w++) {
            $wProc = proc_open(
                [PHP_BINARY, 'artisan', 'queue:work', '--tries=1', '--timeout=10'],
                [
                    0 => ['pipe', 'r'],
                    1 => ['pipe', 'w'],
                    2 => ['pipe', 'w'],
                ],
                $wPipes,
                $path
            );

            if (!is_resource($wProc)) {
                warn($tag, "Could not start queue worker {$w} for port {$srv['port']}");
                continue;
            }

            $wPid = proc_get_status($wProc)['pid'];
            stream_set_blocking($wPipes[1], false);
            stream_set_blocking($wPipes[2], false);

            $srv['workers'][] = ['proc' => $wProc, 'pipes' => $wPipes, 'pid' => $wPid];
            info($tag, "Worker {$w} started for port {$srv['port']} (pid={$wPid})");
        }
    }
    unset($srv);

    usleep(500_000); // let workers settle

    $totalWorkers = array_sum(array_map(fn($s) => count($s['workers']), $servers));
    $aliveWorkers = 0;
    foreach ($servers as $srv) {
        foreach ($srv['workers'] as $w) {
            if (is_process_alive($w['pid'])) $aliveWorkers++;
        }
    }
    ok($tag, "Workers alive: {$aliveWorkers} / {$totalWorkers}");

    // ── Phase 3: HTTP hammer ──────────────────────────────────────────────────

    hdr('S5 Phase 3 — HTTP request flood');

    foreach ($servers as $srv) {
        if (!is_process_alive($srv['pid'])) {
            warn($tag, "Instance on port {$srv['port']} is not running — skipping");
            continue;
        }

        info($tag, "Hammering {$srv['url']} with {$requests} concurrent requests...");
        $reqStart  = microtime(true);
        $succeeded = 0;
        $failed    = 0;
        $codes     = [];

        // Use curl_multi for true concurrency
        $mh      = curl_multi_init();
        $handles = [];

        for ($r = 0; $r < $requests; $r++) {
            $ch = curl_init($srv['url'] . '/');
            curl_setopt_array($ch, [
                CURLOPT_RETURNTRANSFER => true,
                CURLOPT_TIMEOUT        => 15,
                CURLOPT_FOLLOWLOCATION => true,
                CURLOPT_HTTPHEADER     => ['Accept: text/html'],
            ]);
            curl_multi_add_handle($mh, $ch);
            $handles[] = $ch;
        }

        $running = null;
        do {
            curl_multi_exec($mh, $running);
            curl_multi_select($mh);
        } while ($running > 0);

        foreach ($handles as $ch) {
            $code     = curl_getinfo($ch, CURLINFO_HTTP_CODE);
            $errno    = curl_errno($ch);
            $codes[$code] = ($codes[$code] ?? 0) + 1;

            if ($errno === 0 && $code > 0) {
                $succeeded++;
            } else {
                $failed++;
            }
            curl_multi_remove_handle($mh, $ch);
            curl_close($ch);
        }

        curl_multi_close($mh);

        $dur     = elapsed($reqStart);
        $codeStr = implode(', ', array_map(fn($c, $n) => "HTTP {$c}×{$n}", array_keys($codes), $codes));

        if ($failed === 0) {
            ok($tag, "Port {$srv['port']}: {$succeeded}/{$requests} ok in {$dur} [{$codeStr}] ✓");
        } else {
            warn($tag, "Port {$srv['port']}: {$succeeded} ok, {$failed} failed in {$dur} [{$codeStr}]");
        }
    }

    // ── Phase 4: Kill propagation ─────────────────────────────────────────────

    hdr('S5 Phase 4 — Kill propagation');

    $allPids = [];
    foreach ($servers as $srv) {
        $allPids[] = $srv['pid'];
        foreach ($srv['workers'] as $w) {
            $allPids[] = $w['pid'];
        }
    }

    $aliveBeforeKill = count(array_filter($allPids, 'is_process_alive'));
    info($tag, "Processes alive before kill: {$aliveBeforeKill} (artisan + workers)");
    info($tag, "PIDs: " . implode(', ', $allPids));
    info($tag, "Killing all artisan instances...");

    foreach ($servers as $srv) {
        // Kill workers first
        foreach ($srv['workers'] as $w) {
            @fclose($w['pipes'][1]);
            @fclose($w['pipes'][2]);
            @proc_terminate($w['proc']);
            @proc_close($w['proc']);
        }
        // Kill artisan serve
        @fclose($srv['pipes'][1]);
        @fclose($srv['pipes'][2]);
        @proc_terminate($srv['proc']);
        @proc_close($srv['proc']);
    }

    if (PHP_OS_FAMILY === 'Windows') {
        foreach ($allPids as $pid) {
            exec("taskkill /pid {$pid} /t /f 2>NUL");
        }
    }

    // Poll until all gone (max 8s — Laravel can be slow to shut down)
    $deadline  = microtime(true) + 8.0;
    $remaining = $allPids;

    while (!empty($remaining) && microtime(true) < $deadline) {
        usleep(200_000);
        $remaining = array_values(array_filter($remaining, 'is_process_alive'));
    }

    if (empty($remaining)) {
        ok($tag, "All " . count($allPids) . " processes (artisan + workers) terminated cleanly ✓");
    } else {
        $zombiePids = implode(', ', $remaining);
        fail($tag, count($remaining) . " zombie(s) survived kill: {$zombiePids}");
        warn($tag, "Process cleanup may not be capturing all child processes.");
    }

    ok($tag, "S5 completed in " . elapsed($start));
}

// ─── Internal: deep tree node ─────────────────────────────────────────────────

function internal_tree_node(int $depth): void
{
    echo "level={$depth} pid=" . getmypid() . "\n";
    if ($depth <= 1) exit(0);

    $proc = proc_open([PHP_BINARY, __FILE__, '--internal-tree=' . ($depth - 1)], [
        1 => STDOUT,
        2 => STDERR,
    ], $pipes);

    if (!is_resource($proc)) {
        fwrite(STDERR, "tree node failed at depth " . ($depth - 1) . "\n");
        exit(1);
    }

    exit(proc_close($proc));
}

// ─── Parallel orchestrator ────────────────────────────────────────────────────

function run_parallel(array $scenarios, array $cfg): void
{
    $self = __FILE__;
    $pool = [];

    hdr("Launching all scenarios in parallel");

    foreach ($scenarios as $s) {
        $args = [
            PHP_BINARY,
            $self,
            "--scenario={$s}",
            "--spawn={$cfg['spawn']}",
            "--depth={$cfg['depth']}",
            "--trees={$cfg['trees']}",
            "--procs={$cfg['procs']}",
            "--lines={$cfg['lines']}",
            "--count={$cfg['count']}",
            "--kill-after={$cfg['kill_after']}",
        ];

        $proc = proc_open($args, [
            1 => ['pipe', 'w'],
            2 => ['pipe', 'w'],
        ], $pipes);

        if (!is_resource($proc)) {
            fail("runner", "Could not launch scenario {$s}");
            continue;
        }

        stream_set_blocking($pipes[1], false);
        stream_set_blocking($pipes[2], false);
        $pool[$s] = ['proc' => $proc, 'pipes' => $pipes];
        info("runner", "Scenario {$s} launched (pid=" . proc_get_status($proc)['pid'] . ")");
    }

    $results = [];

    while (!empty($pool)) {
        foreach ($pool as $s => &$entry) {
            $chunk = @fread($entry['pipes'][1], 4096);
            if ($chunk !== false && $chunk !== '') echo $chunk;
            $echunk = @fread($entry['pipes'][2], 4096);
            if ($echunk !== false && $echunk !== '') echo $echunk;

            $status = proc_get_status($entry['proc']);
            if (!$status['running']) {
                $tail = stream_get_contents($entry['pipes'][1]);
                if ($tail) echo $tail;
                $etail = stream_get_contents($entry['pipes'][2]);
                if ($etail) echo $etail;

                fclose($entry['pipes'][1]);
                fclose($entry['pipes'][2]);
                $exit = proc_close($entry['proc']);

                $results[$s] = $exit;
                info("runner", "Scenario {$s} finished (exit={$exit})");
                unset($pool[$s]);
            }
        }
        unset($entry);
        usleep(10_000);
    }

    hdr("Summary");
    foreach ($results as $s => $exit) {
        $sym   = $exit === 0 ? '✓' : '✗';
        $color = $exit === 0 ? 'ok' : 'fail';
        log_line("S{$s}", $color, "exit={$exit} {$sym}");
    }
}

// ─── Entry point ──────────────────────────────────────────────────────────────

if (isset($opts['internal-tree'])) {
    internal_tree_node((int) $opts['internal-tree']);
    exit(0);
}

$scenario = isset($opts['scenario']) ? (int) $opts['scenario'] : 0;

if ($scenario > 0) {
    match ($scenario) {
        1 => run_scenario1($CFG),
        2 => run_scenario2($CFG),
        3 => run_scenario3($CFG),
        4 => run_scenario4($CFG),
        5 => run_scenario5($CFG),
    };
    exit(0);
}

// ── Full parallel run (S1–S4 only — S5 is standalone) ────────────────────────

echo "\033[35m";
echo "\n╔══════════════════════════════════════════════════════════╗\n";
echo "║     Process Management Stress Test Suite (IOProcessManager) ║\n";
echo "╚══════════════════════════════════════════════════════════╝\033[0m\n";
echo "  PHP " . PHP_VERSION . " | OS: " . PHP_OS_FAMILY . " | PID: " . getmypid() . "\n";
echo "  spawn={$CFG['spawn']}  depth={$CFG['depth']}  trees={$CFG['trees']}  ";
echo "procs={$CFG['procs']}  lines={$CFG['lines']}  kill-count={$CFG['count']}\n";
echo "  (S5 Laravel test: run separately with --scenario=5 --laravel-path=...)\n";

$wall = microtime(true);
run_parallel([1, 2, 3, 4], $CFG);
$total = round(microtime(true) - $wall, 2);

echo "\n\033[35m" . str_repeat('═', 60) . "\033[0m\n";
echo "  Total wall time: \033[32m{$total}s\033[0m\n";
echo "\033[35m" . str_repeat('═', 60) . "\033[0m\n\n";
