# Releasing

Every push to `master` touching `Sources/`, `Package.swift`, `Packaging/`,
or the build/icon scripts runs `.github/workflows/release.yml`: builds and
zips the app, auto-bumps the patch version (unless the commit already set
one), tags, publishes a GitHub Release, and updates the
`felipepkgs/homebrew-ghostbar` tap. Runs are serialized (`concurrency:
group: release`) so merges seconds apart don't race on the version-bump
commit.

Requires a `HOMEBREW_TAP_TOKEN` repo secret (fine-grained PAT, Contents:
read & write) — already configured.
