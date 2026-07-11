# Gitignore

[![CI](https://github.com/ivan-podgurskiy/gitignore/actions/workflows/ci.yml/badge.svg)](https://github.com/ivan-podgurskiy/gitignore/actions/workflows/ci.yml)
[![Hex pm](https://img.shields.io/hexpm/v/gitignore.svg)](https://hex.pm/packages/gitignore)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Correct gitignore and wildmatch semantics for Elixir.

`Gitignore` answers whether a normalized, `/`-separated relative path is ignored
by gitignore-style rules. It supports negation, directory-only rules, anchoring,
`**`, last-match-wins, nested ignore files, and optional case-insensitive
matching.

## Installation

Add `gitignore` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:gitignore, "~> 0.1.0"}
  ]
end
```

Or depend on the Git repository:

```elixir
{:gitignore, git: "https://github.com/ivan-podgurskiy/gitignore.git"}
```

## Quick start

```elixir
rules = Gitignore.parse("""
_build/
*.beam
!important.beam
""")

matcher = Gitignore.compile(rules)

Gitignore.ignored?(matcher, "_build/dev/lib", type: :directory)
#=> true

Gitignore.ignored?(matcher, "important.beam", type: :file)
#=> false
```

All paths must be binaries relative to the matcher or stack base and must use
`/` as the separator. Normalize Windows paths before calling this library.

This library does not walk the filesystem. It matches paths supplied by callers.

## Semantics

- Last matching rule wins.
- A negated rule starts with `!`.
- A rule ending in `/` only matches directories and their descendants.
- `*` and `?` do not match `/`.
- `**/foo`, `foo/**`, and `foo/**/bar` use git's special globstar rules.
- Re-including a file inside an ignored parent directory is not allowed,
  matching git's parent-exclusion behavior.
- `type: :file | :directory` is required so directory-only rules behave
  correctly.

## Verification

Two fixture suites pin the library to real git behavior:

- **Wildmatch engine:** all 756 cases extracted from git's own
  `t/t3070-wildmatch.sh` test suite (pinned to git v2.48.1), covering the
  wildmatch, iwildmatch, pathmatch, and ipathmatch modes. Regenerate with
  `mix run scripts/extract_t3070.exs`.
- **Ignore-file semantics:** 79 cases whose expectations are produced by
  running `git check-ignore` against materialized repository layouts,
  covering negation and re-inclusion, parent exclusion, anchoring, dir-only
  rules, nested ignore files, escaping, globstar, and `core.ignoreCase`.
  Regenerate with `mix run scripts/gen_ignore_cases.exs`.

## Development

```bash
mix test
mix credo --strict
mix dialyzer
mix docs
```

## License

MIT (c) Ivan Podgurskiy. See [LICENSE](LICENSE).
