defmodule Gitignore do
  @moduledoc """
  Parse and match gitignore-style rules.
  """

  alias Gitignore.{Matcher, Rule}

  @doc "Parses ignore-file content into rules."
  @spec parse(binary()) :: [Rule.t()]
  def parse(content) when is_binary(content) do
    content
    |> String.split("\n", trim: false)
    |> Enum.with_index(1)
    |> Enum.flat_map(fn {line, number} ->
      case Rule.parse(line, number) do
        {:ok, rule} -> [rule]
        :skip -> []
      end
    end)
  end

  @doc "Compiles rules into a matcher."
  @spec compile([Rule.t()], keyword()) :: Matcher.t()
  def compile(rules, opts \\ []), do: Matcher.new(rules, opts)

  @doc "Returns true when the path is ignored."
  @spec ignored?(Matcher.t(), binary(), keyword()) :: boolean()
  def ignored?(%Matcher{} = matcher, path, opts) do
    case check(matcher, path, opts) do
      {:ignored, _rule} -> true
      _other -> false
    end
  end

  @doc "Returns the matching rule, similar to `git check-ignore -v`."
  @spec check(Matcher.t(), binary(), keyword()) ::
          {:ignored | :unignored, Rule.t()} | :not_ignored
  def check(%Matcher{} = matcher, path, opts), do: Matcher.check(matcher, path, opts)

  @doc "Loads `.gitignore` files from `root` into a stack."
  @spec load(Path.t(), keyword()) :: {:ok, Gitignore.Stack.t()} | {:error, term()}
  def load(root, opts \\ []), do: Gitignore.Loader.load(root, opts)
end
