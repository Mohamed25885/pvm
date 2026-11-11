# PVM

PVM is a PHP version manager: it installs several PHP versions side by side and switches between them per machine or per project.

## Language

**Release source**:
A publisher of prebuilt PHP builds that PVM installs from, such as windows.php.net or static-php.
_Avoid_: provider, mirror, fetcher

**Published checksum**:
The SHA-256 a release source publishes for one of its archives.
_Avoid_: hash, fingerprint, digest

**Verified install**:
An install whose downloaded archive matched its published checksum.

**Unverified install**:
An install of an archive that has no published checksum, done only on the user's explicit request; its actual SHA-256 is still recorded.
_Avoid_: unsafe install, insecure install
