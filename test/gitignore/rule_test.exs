defmodule Gitignore.RuleTest do
  use ExUnit.Case, async: true

  alias Gitignore.Rule

  test "skips empty lines and comments" do
    assert Rule.parse("", 1) == :skip
    assert Rule.parse("   ", 2) == :skip
    assert Rule.parse("# comment", 3) == :skip
  end

  test "keeps escaped comment and negation prefixes" do
    assert {:ok, rule} = Rule.parse("\\#literal", 1)
    assert rule.pattern == "#literal"
    refute rule.negated?

    assert {:ok, rule} = Rule.parse("\\!literal", 2)
    assert rule.pattern == "!literal"
    refute rule.negated?
  end

  test "parses negation" do
    assert {:ok, rule} = Rule.parse("!important.beam", 4)
    assert rule.pattern == "important.beam"
    assert rule.negated?
    assert rule.source == "!important.beam"
    assert rule.line == 4
  end

  test "trims unescaped trailing spaces and preserves escaped spaces" do
    assert {:ok, rule} = Rule.parse("foo   ", 1)
    assert rule.pattern == "foo"

    assert {:ok, rule} = Rule.parse("foo\\  ", 2)
    assert rule.pattern == "foo "
  end

  test "parses directory-only and anchoring" do
    assert {:ok, rule} = Rule.parse("build/", 1)
    assert rule.dir_only?
    refute rule.anchored?
    assert rule.basename?

    assert {:ok, rule} = Rule.parse("/build", 2)
    refute rule.dir_only?
    assert rule.anchored?
    refute rule.basename?

    assert {:ok, rule} = Rule.parse("src/*.beam", 3)
    assert rule.anchored?
    refute rule.basename?
  end

  test "handles CRLF" do
    assert {:ok, rule} = Rule.parse("foo\r\n", 1)
    assert rule.pattern == "foo"
  end
end
