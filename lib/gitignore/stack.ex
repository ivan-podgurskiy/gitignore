defmodule Gitignore.Stack do
  @moduledoc false

  alias Gitignore.Matcher

  defstruct matchers: [], casefold?: false

  @type t :: %__MODULE__{matchers: [Matcher.t()], casefold?: boolean()}

  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{casefold?: Keyword.get(opts, :casefold, false)}
  end

  @spec push(t(), binary(), [Gitignore.Rule.t()] | Matcher.t()) :: t()
  def push(%__MODULE__{} = stack, base, %Matcher{} = matcher) do
    matcher = %Matcher{matcher | base: normalize_base(base), casefold?: stack.casefold?}
    %__MODULE__{stack | matchers: sort_matchers([matcher | stack.matchers])}
  end

  def push(%__MODULE__{} = stack, base, rules) when is_list(rules) do
    push(stack, base, Matcher.new(rules, base: normalize_base(base), casefold: stack.casefold?))
  end

  @spec ignored?(t(), binary(), keyword()) :: boolean()
  def ignored?(%__MODULE__{} = stack, path, opts) do
    case check(stack, path, opts) do
      {:ignored, _rule} -> true
      _other -> false
    end
  end

  @spec check(t(), binary(), keyword()) ::
          {:ignored | :unignored, Gitignore.Rule.t()} | :not_ignored
  def check(%__MODULE__{} = stack, path, opts) do
    stack.matchers
    |> applicable_matchers(path)
    |> Enum.find_value(:not_ignored, fn matcher ->
      relative = relative_to_base(path, matcher.base)

      case Matcher.check(matcher, relative, opts) do
        :not_ignored -> nil
        result -> result
      end
    end)
  end

  defp applicable_matchers(matchers, path) do
    Enum.filter(matchers, fn matcher -> under_base?(path, matcher.base) end)
  end

  defp under_base?(_path, "."), do: true
  defp under_base?(path, base), do: path == base or String.starts_with?(path, base <> "/")

  defp relative_to_base(path, "."), do: path
  defp relative_to_base(path, base) when path == base, do: "."
  defp relative_to_base(path, base), do: String.replace_prefix(path, base <> "/", "")

  defp sort_matchers(matchers) do
    Enum.sort_by(matchers, fn matcher -> depth(matcher.base) end, :desc)
  end

  defp depth("."), do: 0
  defp depth(base), do: base |> String.split("/", trim: true) |> length()

  defp normalize_base("."), do: "."
  defp normalize_base("./" <> rest), do: normalize_base(rest)
  defp normalize_base(base), do: String.trim(base, "/")
end
