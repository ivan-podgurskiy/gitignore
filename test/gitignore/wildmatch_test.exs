defmodule Gitignore.WildmatchTest do
  use ExUnit.Case, async: true

  alias Gitignore.Wildmatch

  describe "match?/3 literals and simple wildcards" do
    test "matches exact binaries" do
      assert Wildmatch.match?("README.md", "README.md")
      refute Wildmatch.match?("README.md", "readme.md")
    end

    test "question mark matches one non-slash byte in pathname mode" do
      assert Wildmatch.match?("lib/?.ex", "lib/a.ex")
      refute Wildmatch.match?("lib/?.ex", "lib/ab.ex")
      refute Wildmatch.match?("lib/?.ex", "lib//.ex")
    end

    test "star does not cross slash in pathname mode" do
      assert Wildmatch.match?("*.ex", "gitignore.ex")
      refute Wildmatch.match?("*.ex", "lib/gitignore.ex")
    end

    test "star crosses slash when pathname mode is disabled" do
      assert Wildmatch.match?("*.ex", "lib/gitignore.ex", pathname: false)
    end

    test "backslash escapes wildcard tokens" do
      assert Wildmatch.match?("file\\*.txt", "file*.txt")
      refute Wildmatch.match?("file\\*.txt", "file123.txt")
    end

    test "casefold compares ASCII case-insensitively" do
      assert Wildmatch.match?("README.md", "readme.MD", casefold: true)
      refute Wildmatch.match?("README.md", "readme.MD", casefold: false)
    end
  end

  describe "match?/3 character classes" do
    test "matches ranges and negated ranges" do
      assert Wildmatch.match?("file[0-9].txt", "file7.txt")
      refute Wildmatch.match?("file[0-9].txt", "filex.txt")
      assert Wildmatch.match?("file[!0-9].txt", "filex.txt")
      refute Wildmatch.match?("file[!0-9].txt", "file7.txt")
      assert Wildmatch.match?("file[^0-9].txt", "filex.txt")
    end

    test "supports POSIX classes" do
      assert Wildmatch.match?("[[:alpha:]].ex", "a.ex")
      refute Wildmatch.match?("[[:alpha:]].ex", "7.ex")
      assert Wildmatch.match?("[[:digit:]].ex", "7.ex")
    end
  end

  describe "match?/3 globstar semantics" do
    test "leading globstar slash matches zero or more directories" do
      assert Wildmatch.match?("**/foo.ex", "foo.ex")
      assert Wildmatch.match?("**/foo.ex", "lib/foo.ex")
      assert Wildmatch.match?("**/foo.ex", "apps/web/lib/foo.ex")
    end

    test "trailing slash globstar matches everything below directory" do
      assert Wildmatch.match?("foo/**", "foo/bar")
      assert Wildmatch.match?("foo/**", "foo/bar/baz")
      refute Wildmatch.match?("foo/**", "bar/foo/baz")
    end

    test "middle slash globstar matches zero or more directories" do
      assert Wildmatch.match?("a/**/b", "a/b")
      assert Wildmatch.match?("a/**/b", "a/x/b")
      assert Wildmatch.match?("a/**/b", "a/x/y/b")
    end

    test "double star outside git-special positions behaves like repeated star" do
      assert Wildmatch.match?("ab**cd", "abcd")
      assert Wildmatch.match?("ab**cd", "abXYZcd")
      refute Wildmatch.match?("ab**cd", "ab/x/cd")
    end
  end

  describe "t3070-derived fixtures" do
    @fixture_path Path.expand("../fixtures/wildmatch_cases.exs", __DIR__)
    @cases Code.eval_file(@fixture_path) |> elem(0)

    for %{name: name, pattern: pattern, path: path, opts: opts, expected: expected} <- @cases do
      @tag fixture: true
      test name do
        assert Wildmatch.match?(unquote(pattern), unquote(path), unquote(Macro.escape(opts))) ==
                 unquote(expected)
      end
    end
  end
end
