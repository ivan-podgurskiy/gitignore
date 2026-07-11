defmodule Gitignore.IgnoreCasesTest do
  # Fixture-driven ignore-semantics tests. Every expectation in
  # test/fixtures/ignore_cases.exs was produced by `git check-ignore`;
  # see scripts/gen_ignore_cases.exs.
  use ExUnit.Case, async: true

  alias Gitignore.Stack

  @fixture_path Path.expand("../fixtures/ignore_cases.exs", __DIR__)
  @cases Code.eval_file(@fixture_path) |> elem(0)

  for fixture_case <- @cases do
    check_rule? = fixture_case.rule != nil and map_size(fixture_case.files) == 1
    rule_line = if check_rule?, do: fixture_case.rule.line
    expected_status = if fixture_case.expected, do: :ignored, else: :unignored

    @tag fixture: true
    test fixture_case.name do
      c = unquote(Macro.escape(fixture_case))

      stack =
        Enum.reduce(c.files, Stack.new(casefold: c.casefold), fn {file, content}, stack ->
          Stack.push(stack, Path.dirname(file), Gitignore.parse(content))
        end)

      assert Stack.ignored?(stack, c.path, type: c.type) == c.expected

      # For single-file scenarios, check/3 must attribute the same rule line
      # as `git check-ignore -v` (rule sources are ambiguous across files).
      if unquote(check_rule?) do
        assert {unquote(expected_status), rule} = Stack.check(stack, c.path, type: c.type)
        assert rule.line == unquote(rule_line)
      end
    end
  end
end
