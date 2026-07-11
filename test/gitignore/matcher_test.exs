defmodule Gitignore.MatcherTest do
  use ExUnit.Case, async: true

  test "last match wins with negation" do
    matcher =
      """
      *.beam
      !important.beam
      """
      |> Gitignore.parse()
      |> Gitignore.compile()

    assert Gitignore.ignored?(matcher, "other.beam", type: :file)
    refute Gitignore.ignored?(matcher, "important.beam", type: :file)
  end

  test "directory-only rules require directory type" do
    matcher = Gitignore.compile(Gitignore.parse("build/\n"))

    assert Gitignore.ignored?(matcher, "build", type: :directory)
    assert Gitignore.ignored?(matcher, "build/output.o", type: :file)
    refute Gitignore.ignored?(matcher, "build", type: :file)
  end

  test "basename rules match at any depth" do
    matcher = Gitignore.compile(Gitignore.parse("*.beam\n"))

    assert Gitignore.ignored?(matcher, "foo.beam", type: :file)
    assert Gitignore.ignored?(matcher, "lib/foo.beam", type: :file)
  end

  test "anchored rules match relative to matcher base" do
    matcher = Gitignore.compile(Gitignore.parse("/build\nsrc/*.beam\n"))

    assert Gitignore.ignored?(matcher, "build", type: :directory)
    refute Gitignore.ignored?(matcher, "apps/build", type: :directory)
    assert Gitignore.ignored?(matcher, "src/foo.beam", type: :file)
    refute Gitignore.ignored?(matcher, "apps/src/foo.beam", type: :file)
  end

  test "parent exclusion prevents re-including children" do
    matcher =
      """
      build/
      !build/keep.txt
      """
      |> Gitignore.parse()
      |> Gitignore.compile()

    assert Gitignore.ignored?(matcher, "build/keep.txt", type: :file)
  end

  test "check returns matching rule" do
    matcher = Gitignore.compile(Gitignore.parse("*.beam\n!important.beam\n"))

    assert {:ignored, ignored_rule} = Gitignore.check(matcher, "other.beam", type: :file)
    assert ignored_rule.source == "*.beam"

    assert {:unignored, unignored_rule} = Gitignore.check(matcher, "important.beam", type: :file)
    assert unignored_rule.source == "!important.beam"

    assert Gitignore.check(matcher, "lib/foo.ex", type: :file) == :not_ignored
  end

  test "case sensitivity is configurable" do
    sensitive = Gitignore.compile(Gitignore.parse("README.md\n"))
    insensitive = Gitignore.compile(Gitignore.parse("README.md\n"), casefold: true)

    refute Gitignore.ignored?(sensitive, "readme.md", type: :file)
    assert Gitignore.ignored?(insensitive, "readme.md", type: :file)
  end

  # Oracle-generated ignore-semantics fixtures are exercised in
  # test/gitignore/ignore_cases_test.exs.
end
