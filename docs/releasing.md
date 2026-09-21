# Releasing

Every push to `master` that touches `Sources/`, `Package.swift`,
`Packaging/`, or the build/icon scripts triggers `.github/workflows/release.yml`:
it builds and zips `GhostBar.app`, auto-bumps `Packaging/Info.plist`'s patch
version (unless that commit already set a fresh, unreleased version — e.g. a
manual minor/major bump), tags and publishes a GitHub Release, then updates
the `felipepkgs/homebrew-ghostbar` cask's version and checksum. No manual
`build_app.sh` / `gh release create` dance needed for routine changes.

The Homebrew-tap step needs a `HOMEBREW_TAP_TOKEN` repo secret — a
fine-grained PAT scoped to `felipepkgs/homebrew-ghostbar` with Contents:
read & write, created at github.com/settings/tokens and set via
`gh secret set HOMEBREW_TAP_TOKEN --repo felipepkgs/GhostBar`. Until that
secret exists, the GhostBar release itself still succeeds — only the tap
update fails.
