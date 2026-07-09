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

## Development

```bash
mix test
mix credo --strict
mix dialyzer
mix docs
```

## License

MIT (c) Ivan Podgurskiy. See [LICENSE](LICENSE).
