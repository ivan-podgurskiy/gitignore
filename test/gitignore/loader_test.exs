defmodule Gitignore.LoaderTest do
  use ExUnit.Case, async: true

  test "loads root .gitignore" do
    tmp = tmp_dir()
    File.write!(Path.join(tmp, ".gitignore"), "_build/\n")

    assert {:ok, stack} = Gitignore.load(tmp)
    assert Gitignore.Stack.ignored?(stack, "_build", type: :directory)
  end

  test "loads nested .gitignore files when recursive" do
    tmp = tmp_dir()
    File.mkdir_p!(Path.join(tmp, "apps/web"))
    File.write!(Path.join(tmp, ".gitignore"), "*.beam\n")
    File.write!(Path.join(tmp, "apps/web/.gitignore"), "!important.beam\n")

    assert {:ok, stack} = Gitignore.load(tmp, recursive: true)
    assert Gitignore.Stack.ignored?(stack, "apps/api/important.beam", type: :file)
    refute Gitignore.Stack.ignored?(stack, "apps/web/important.beam", type: :file)
  end

  defp tmp_dir do
    path = Path.join(System.tmp_dir!(), "gitignore-loader-#{System.unique_integer([:positive])}")
    File.mkdir_p!(path)
    path
  end
end
