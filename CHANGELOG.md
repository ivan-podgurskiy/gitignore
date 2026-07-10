# Changelog

## v0.1.0 - Unreleased

- Added `Gitignore.Wildmatch.match?/3`.
- Added parsing and matching for gitignore rules.
- Added nested ignore-file stacks.
- Added optional `.gitignore` loader.
- Added fixture-backed tests for wildmatch and ignore semantics.
- Verified the wildmatch engine against all 756 cases extracted from git's
  t3070-wildmatch.sh (git v2.48.1) via `scripts/extract_t3070.exs`, rewriting
  the engine as a byte-oriented matcher with git's abort semantics along the
  way. Matching is now byte-based: `?` matches one byte, malformed character
  classes fail the whole match, and `dir/**` no longer matches `dir` itself.
