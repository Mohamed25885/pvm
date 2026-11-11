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

**Slot**:
The folder `versions/<X.Y>` holding the one installed patch of a minor version; `pvm update X.Y` replaces the patch inside it.

**Linked slot**:
A slot that is a link to a PHP folder the user already has, made by `pvm link`; PVM never edits the folder except to add an extension on request.

**Extension install**:
`pvm ext install` counts as the user's explicit request for an unverified install, since extension downloads publish no checksum; the file's SHA-256 is recorded and the extension marked unverified.
