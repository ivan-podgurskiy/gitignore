defmodule Gitignore.Stack do
  @moduledoc """
  Stack of directory-scoped gitignore matchers.

  A stack models nested `.gitignore` files where deeper files have stronger
  priority than shallower files.
  """

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
    type = Keyword.fetch!(opts, :type)
    path = normalize_base(path)

    case excluded_parent(stack, path) do
      {:ignored, rule} -> {:ignored, rule}
      :not_ignored -> direct_check(stack, path, type)
    end
  end

  # Parent exclusion must span layers: a directory excluded by a shallow
  # .gitignore blocks re-inclusion by deeper ones, so each ancestor gets a
  # full stack evaluation before the path itself is considered.
  defp excluded_parent(stack, path) do
    path
    |> parent_paths()
    |> Enum.find_value(:not_ignored, fn parent ->
      case direct_check(stack, parent, :directory) do
        {:ignored, rule} -> {:ignored, rule}
        _other -> nil
      end
    end)
  end

  defp direct_check(stack, path, type) do
    stack.matchers
    |> applicable_matchers(path)
    |> Enum.find_value(:not_ignored, fn matcher ->
      relative = relative_to_base(path, matcher.base)

      case Matcher.check(matcher, relative, type: type, parents: false) do
        :not_ignored -> nil
        result -> result
      end
    end)
  end

  defp parent_paths(path) do
    path
    |> String.split("/", trim: true)
    |> Enum.drop(-1)
    |> Enum.scan([], fn part, acc -> acc ++ [part] end)
    |> Enum.map(&Enum.join(&1, "/"))
  end

  defp applicable_matchers(matchers, path) do
    Enum.filter(matchers, fn matcher -> under_base?(path, matcher.base) end)
  end

  # Rules in a directory's own .gitignore never apply to that directory
  # itself, so containment is strict.
  defp under_base?(_path, "."), do: true
  defp under_base?(path, base), do: String.starts_with?(path, base <> "/")

  defp relative_to_base(path, "."), do: path
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
