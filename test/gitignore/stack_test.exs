defmodule Gitignore.StackTest do
  use ExUnit.Case, async: true

  alias Gitignore.Stack

  test "deeper ignore files have stronger priority" do
    stack =
      Stack.new()
      |> Stack.push(".", Gitignore.parse("*.beam\n"))
      |> Stack.push("apps/web", Gitignore.parse("!important.beam\n"))

    assert Stack.ignored?(stack, "apps/api/important.beam", type: :file)
    refute Stack.ignored?(stack, "apps/web/important.beam", type: :file)
  end

  test "nested basename rules apply relative to their base" do
    stack =
      Stack.new()
      |> Stack.push("apps/web", Gitignore.parse("node_modules/\n"))

    assert Stack.ignored?(stack, "apps/web/node_modules", type: :directory)
    assert Stack.ignored?(stack, "apps/web/assets/node_modules", type: :directory)
    refute Stack.ignored?(stack, "apps/api/node_modules", type: :directory)
  end

  test "anchored nested rules apply to nested base" do
    stack =
      Stack.new()
      |> Stack.push("apps/web", Gitignore.parse("/tmp\n"))

    assert Stack.ignored?(stack, "apps/web/tmp", type: :directory)
    refute Stack.ignored?(stack, "apps/web/lib/tmp", type: :directory)
  end
end
