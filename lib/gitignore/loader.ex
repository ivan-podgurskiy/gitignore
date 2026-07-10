defmodule Gitignore.Loader do
  @moduledoc false

  alias Gitignore.Stack

  @spec load(Path.t(), keyword()) :: {:ok, Stack.t()} | {:error, term()}
  def load(root, opts \\ []) do
    recursive? = Keyword.get(opts, :recursive, false)
    casefold? = Keyword.get(opts, :casefold, false)
    root = Path.expand(root)

    case File.dir?(root) do
      true ->
        stack = Stack.new(casefold: casefold?)
        {:ok, load_into_stack(stack, root, root, recursive?)}

      false ->
        {:error, :enoent}
    end
  end

  defp load_into_stack(stack, root, dir, recursive?) do
    stack = maybe_push_ignore(stack, root, dir)

    if recursive? do
      dir
      |> File.ls!()
      |> Enum.map(&Path.join(dir, &1))
      |> Enum.filter(&File.dir?/1)
      |> Enum.reject(&(Path.basename(&1) == ".git"))
      |> Enum.reduce(stack, fn child, acc -> load_into_stack(acc, root, child, true) end)
    else
      stack
    end
  end

  defp maybe_push_ignore(stack, root, dir) do
    ignore_path = Path.join(dir, ".gitignore")

    if File.regular?(ignore_path) do
      content = File.read!(ignore_path)
      base = relative_base(root, dir)
      Stack.push(stack, base, Gitignore.parse(content))
    else
      stack
    end
  end

  defp relative_base(root, dir) when root == dir, do: "."
  defp relative_base(root, dir), do: Path.relative_to(dir, root)
end
