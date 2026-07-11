# Gitignore

[![CI](https://github.com/ivan-podgurskiy/gitignore/actions/workflows/ci.yml/badge.svg)](https://github.com/ivan-podgurskiy/gitignore/actions/workflows/ci.yml)
[![Hex pm](https://img.shields.io/hexpm/v/gitignore.svg)](https://hex.pm/packages/gitignore)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Correct gitignore and wildmatch semantics for Elixir.

`Gitignore` answers whether a normalized, `/`-separated relative path is ignored
by gitignore-style rules. It supports negation, directory-only rules, anchoring,
`**`, last-match-wins, nested ignore files, and optional case-insensitive
matching.

Use it when a tool needs to respect `.gitignore`: language servers, AI agents,
MCP servers, code generators, refactoring tools, file watchers, static site
generators, and anything else that reads a source tree.

## Why not glob?

`.gitignore` is not a plain glob format. It is an ordered rule language with
negation, directory-only rules, nested files, and Git's wildmatch behavior.

| Feature | `Path.wildcard/2` / glob | `Gitignore` |
| --- | --- | --- |
| Negation with `!` | No | Yes |
| Last matching rule wins | No | Yes |
| Directory-only rules like `build/` | No | Yes |
| Anchoring like `/tmp` or `src/*.beam` | Different language | Git-compatible |
| Nested `.gitignore` files | No | Yes |
| Parent-exclusion behavior | No | Yes |
| Git wildmatch `**` semantics | Different language | Verified against Git |

This matters for tooling. A matcher that treats `.gitignore` as "just glob"
can index ignored build artifacts, miss generated files, or accidentally read
paths that Git itself would ignore.

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

Use `check/3` when you need the rule that made the decision:

```elixir
Gitignore.check(matcher, "other.beam", type: :file)
#=> {:ignored, %Gitignore.Rule{source: "*.beam", line: 2}}

Gitignore.check(matcher, "important.beam", type: :file)
#=> {:unignored, %Gitignore.Rule{source: "!important.beam", line: 3}}
```

## Nested ignore files

Use `Gitignore.Stack` when rules come from nested `.gitignore` files. Deeper
ignore files have stronger priority, matching Git's behavior.

```elixir
stack =
  Gitignore.Stack.new()
  |> Gitignore.Stack.push(".", Gitignore.parse("*.beam\n"))
  |> Gitignore.Stack.push("apps/web", Gitignore.parse("!important.beam\n"))

Gitignore.Stack.ignored?(stack, "apps/api/important.beam", type: :file)
#=> true

Gitignore.Stack.ignored?(stack, "apps/web/important.beam", type: :file)
#=> false
```

For convenience, `Gitignore.load/2` can load `.gitignore` files from disk:

```elixir
{:ok, stack} = Gitignore.load(".", recursive: true)
Gitignore.Stack.ignored?(stack, "_build/dev/lib/app/ebin/app.beam", type: :file)
```

The core matcher does not walk your project tree or enumerate files. It answers
whether a path you provide is ignored. The `Gitignore.load/2` helper is the
only API that reads from disk, and it only loads `.gitignore` files.

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
- All paths must be binaries relative to the matcher or stack base and must use
  `/` as the separator. Normalize Windows paths before calling this library.

Some examples that often break naive matchers:

```gitignore
# Parent exclusion: keep.txt is still ignored because build/ is ignored.
build/
!build/keep.txt

# Directory-only rule: matches a directory named cache at any depth.
cache/

# Anchored path rule: matches tmp only beside this .gitignore file.
/tmp

# Globstar follows Git wildmatch rules.
**/logs
a/**/b
```

## What is not included

Version 0.1 focuses on Git-compatible `.gitignore` matching. It does not include
a filesystem walker, `.dockerignore` or `.npmignore` dialects, global Git
excludes, or `$GIT_DIR/info/exclude` helpers. Callers can load those rule files
themselves and push them into a `Gitignore.Stack`.

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
