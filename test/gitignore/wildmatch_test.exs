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
end
