# Generates test/fixtures/ignore_cases.exs by running the curated scenarios
# below through real `git check-ignore` in throwaway repositories.
#
# Usage:
#
#     mix run scripts/gen_ignore_cases.exs
#
# Every expectation in the fixture is produced by git itself, never written
# by hand: the boolean comes from `git check-ignore -q` and the matched rule
# from `git check-ignore -v -z`. Scenarios cover the ignore-file semantics
# from git's t0008 suite: negation and re-inclusion, parent exclusion,
# anchoring, dir-only rules, nested ignore files, escaping, globstar, and
# core.ignoreCase. Review the fixture diff on regeneration.
defmodule GenIgnoreCases do
  @fixture_path "test/fixtures/ignore_cases.exs"

  defp scenarios do
    [
      %{
        name: "basic negation",
        files: %{".gitignore" => "*.beam\n!important.beam\n"},
        queries: [
          {"other.beam", :file},
          {"important.beam", :file},
          {"lib/foo.beam", :file},
          {"lib/important.beam", :file}
        ]
      },
      %{
        name: "dir-only parent exclusion blocks re-include",
        files: %{".gitignore" => "build/\n!build/keep.txt\n"},
        queries: [
          {"build", :directory},
          {"build/keep.txt", :file},
          {"build/other.txt", :file},
          {"build/sub/deep.txt", :file}
        ]
      },
      %{
        name: "contents-only exclusion allows re-include",
        files: %{".gitignore" => "build/*\n!build/keep.txt\n"},
        queries: [
          {"build", :directory},
          {"build/keep.txt", :file},
          {"build/other.txt", :file}
        ]
      },
      %{
        name: "plain anchored rule excludes directory contents",
        files: %{".gitignore" => "/foo\n"},
        queries: [
          {"foo", :directory},
          {"foo/bar", :file},
          {"foo/sub/deep.txt", :file},
          {"other/foo/bar", :file}
        ]
      },
      %{
        name: "basename rule matches directories at any depth",
        files: %{".gitignore" => "node_modules\n"},
        queries: [
          {"node_modules", :directory},
          {"apps/node_modules", :directory},
          {"apps/node_modules/foo.js", :file},
          {"apps/web/node_modules/pkg/index.js", :file}
        ]
      },
      %{
        name: "re-include inside basename-excluded directory is blocked",
        files: %{".gitignore" => "node_modules\n!node_modules/keep.js\n"},
        queries: [
          {"node_modules/keep.js", :file},
          {"apps/node_modules/keep.js", :file}
        ]
      },
      %{
        name: "dir-only rule ignores a directory",
        files: %{".gitignore" => "cache/\n"},
        queries: [
          {"cache", :directory},
          {"cache/entry", :file},
          {"deep/cache", :directory},
          {"deep/cache/entry", :file}
        ]
      },
      %{
        name: "dir-only rule does not match a file",
        files: %{".gitignore" => "cache/\n"},
        queries: [{"cache", :file}]
      },
      %{
        name: "anchoring",
        files: %{".gitignore" => "/tmp\ndoc/frotz\nsrc/*.beam\n"},
        queries: [
          {"tmp", :directory},
          {"nested/tmp", :directory},
          {"doc/frotz", :directory},
          {"a/doc/frotz", :directory},
          {"src/foo.beam", :file},
          {"apps/src/foo.beam", :file}
        ]
      },
      %{
        name: "trailing spaces",
        files: %{".gitignore" => "artifact   \nkeep\\ \n"},
        queries: [
          {"artifact", :file},
          {"keep ", :file},
          {"keep", :file}
        ]
      },
      %{
        name: "escaped leading hash and bang",
        files: %{".gitignore" => "\\#secret\n\\!secret\n"},
        queries: [
          {"#secret", :file},
          {"!secret", :file}
        ]
      },
      %{
        name: "globstar rules",
        files: %{".gitignore" => "**/logs\nbuild/**\na/**/b\n"},
        queries: [
          {"logs", :directory},
          {"x/y/logs", :directory},
          {"build", :directory},
          {"build/out.o", :file},
          {"build/sub/out.o", :file},
          {"a/b", :directory},
          {"a/x/b", :directory},
          {"a/x/y/b", :directory},
          {"z/a/b", :directory}
        ]
      },
      %{
        name: "leading globstar dir-only",
        files: %{".gitignore" => "**/temp/\n"},
        queries: [
          {"temp", :directory},
          {"x/temp", :directory},
          {"x/temp/f.txt", :file}
        ]
      },
      %{
        name: "wildcards and classes",
        files: %{".gitignore" => "file?.txt\n[a-c].txt\n*.sw[po]\n"},
        queries: [
          {"filea.txt", :file},
          {"file.txt", :file},
          {"b.txt", :file},
          {"d.txt", :file},
          {"x.swp", :file},
          {"x.swq", :file}
        ]
      },
      %{
        name: "comments blank lines and crlf",
        files: %{".gitignore" => "# comment\n\nfoo\r\nbar\n"},
        queries: [
          {"foo", :file},
          {"bar", :file},
          {"# comment", :file}
        ]
      },
      %{
        name: "negated dir-only rule",
        files: %{".gitignore" => "build/\n!build/\n"},
        queries: [
          {"build", :directory},
          {"build/x", :file}
        ]
      },
      %{
        name: "star does not cross directories in path rules",
        files: %{".gitignore" => "foo/*/bar\n"},
        queries: [
          {"foo/x/bar", :directory},
          {"foo/bar", :file},
          {"foo/x/y/bar", :file}
        ]
      },
      %{
        name: "nested gitignore negation",
        files: %{
          ".gitignore" => "*.beam\n",
          "apps/web/.gitignore" => "!important.beam\n"
        },
        queries: [
          {"important.beam", :file},
          {"apps/api/important.beam", :file},
          {"apps/web/important.beam", :file},
          {"apps/web/lib/important.beam", :file}
        ]
      },
      %{
        name: "nested gitignore anchoring",
        files: %{"apps/web/.gitignore" => "/tmp\n"},
        queries: [
          {"apps/web/tmp", :directory},
          {"apps/web/lib/tmp", :directory},
          {"apps/tmp", :directory}
        ]
      },
      %{
        name: "deeper gitignore overrides shallower",
        files: %{
          ".gitignore" => "*.log\n",
          "sub/.gitignore" => "!debug.log\n"
        },
        queries: [
          {"debug.log", :file},
          {"sub/debug.log", :file},
          {"sub/other.log", :file}
        ]
      },
      %{
        name: "nested parent exclusion crosses gitignore layers",
        files: %{
          ".gitignore" => "build/\n",
          "apps/web/.gitignore" => "!keep.txt\n"
        },
        queries: [
          {"apps/web/build/keep.txt", :file},
          {"apps/web/keep.txt", :file}
        ]
      },
      %{
        name: "casefold matching",
        casefold: true,
        files: %{".gitignore" => "README.md\nBuild/\n*.Beam\n!Important.beam\n"},
        queries: [
          {"readme.MD", :file},
          {"BUILD", :directory},
          {"foo.beam", :file},
          {"important.BEAM", :file}
        ]
      }
    ]
  end

  def run do
    {version_out, 0} = System.cmd("git", ["--version"])
    git_version = String.trim(version_out)

    cases = Enum.flat_map(scenarios(), &scenario_cases/1)
    File.write!(@fixture_path, render(cases, git_version))
    {_, 0} = System.cmd("mix", ["format", @fixture_path])
    IO.puts("wrote #{length(cases)} cases to #{@fixture_path} (oracle: #{git_version})")
  end

  defp scenario_cases(scenario) do
    casefold? = Map.get(scenario, :casefold, false)
    repo = repo_dir()

    try do
      init_repo(repo, casefold?)
      Enum.each(scenario.files, fn {path, content} -> write_file(repo, path, content) end)
      Enum.each(scenario.queries, fn query -> materialize(repo, query) end)

      Enum.map(scenario.queries, fn {path, type} ->
        %{
          name: "#{scenario.name}: #{inspect(path)} (#{type})",
          casefold: casefold?,
          files: scenario.files,
          path: path,
          type: type,
          expected: oracle_ignored?(repo, path),
          rule: oracle_rule(repo, path)
        }
      end)
    after
      File.rm_rf!(repo)
    end
  end

  defp repo_dir do
    path = Path.join(System.tmp_dir!(), "gitignore-oracle-#{System.unique_integer([:positive])}")
    File.mkdir_p!(path)
    path
  end

  defp init_repo(repo, casefold?) do
    {_, 0} = System.cmd("git", ["init", "-q"], cd: repo)
    {_, 0} = System.cmd("git", ["config", "core.ignorecase", to_string(casefold?)], cd: repo)
  end

  defp write_file(repo, path, content) do
    full = Path.join(repo, path)
    File.mkdir_p!(Path.dirname(full))
    File.write!(full, content)
  end

  defp materialize(repo, {path, :directory}), do: File.mkdir_p!(Path.join(repo, path))

  defp materialize(repo, {path, :file}) do
    full = Path.join(repo, path)
    File.mkdir_p!(Path.dirname(full))
    File.touch!(full)
  end

  defp oracle_ignored?(repo, path) do
    case System.cmd("git", ["check-ignore", "-q", "--", path], cd: repo) do
      {_, 0} -> true
      {_, 1} -> false
      {out, status} -> raise "check-ignore -q failed (#{status}) for #{inspect(path)}: #{out}"
    end
  end

  defp oracle_rule(repo, path) do
    case System.cmd("git", ["check-ignore", "-v", "--", path], cd: repo) do
      {"", 1} ->
        nil

      {out, status} when status in [0, 1] ->
        parse_verbose(String.trim_trailing(out, "\n"), path)

      {out, status} ->
        raise "check-ignore -v failed (#{status}) for #{inspect(path)}: #{out}"
    end
  end

  # Output shape: "<source>:<linenum>:<pattern>\t<pathname>". Scenario
  # patterns never contain tabs and sources never contain colons, so we can
  # split at the last tab and then twice from the left.
  defp parse_verbose(line, path) do
    {left, _shown_path} =
      case :binary.matches(line, "\t") do
        [] ->
          raise "unparseable check-ignore -v output for #{inspect(path)}: #{inspect(line)}"

        matches ->
          {pos, 1} = List.last(matches)
          String.split_at(line, pos)
      end

    [source, linenum, pattern] = String.split(left, ":", parts: 3)
    %{source: source, line: String.to_integer(linenum), pattern: pattern}
  end

  defp render(cases, git_version) do
    entries = Enum.map_join(cases, ",\n", &format_case/1)

    """
    # Generated by scripts/gen_ignore_cases.exs. DO NOT EDIT BY HAND.
    #
    # Every expectation was produced by `git check-ignore` (#{git_version})
    # running against the scenario's materialized file layout. `expected` is
    # the exit status of check-ignore -q; `rule` is the matched pattern from
    # check-ignore -v (present even for negated matches, as in git).
    #
    # Regenerate: mix run scripts/gen_ignore_cases.exs and review the diff.
    [
    #{entries}
    ]
    """
  end

  defp format_case(c) do
    """
    %{
      name: #{inspect(c.name)},
      casefold: #{c.casefold},
      files: #{inspect(c.files)},
      path: #{inspect(c.path)},
      type: #{inspect(c.type)},
      expected: #{c.expected},
      rule: #{inspect(c.rule)}
    }\
    """
  end
end

GenIgnoreCases.run()
