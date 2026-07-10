defmodule Gitignore.Matcher do
  @moduledoc false

  alias Gitignore.{Rule, Wildmatch}

  defstruct rules: [], base: ".", casefold?: false

  @type t :: %__MODULE__{
          rules: [Rule.t()],
          base: binary(),
          casefold?: boolean()
        }

  @spec new([Rule.t()], keyword()) :: t()
  def new(rules, opts \\ []) when is_list(rules) do
    %__MODULE__{
      rules: rules,
      base: Keyword.get(opts, :base, "."),
      casefold?: Keyword.get(opts, :casefold, false)
    }
  end

  @spec check(t(), binary(), keyword()) :: {:ignored | :unignored, Rule.t()} | :not_ignored
  def check(%__MODULE__{} = matcher, path, opts) when is_binary(path) do
    type = Keyword.fetch!(opts, :type)
    path = normalize_relative(path)

    if parent_excluded?(matcher, path) do
      {:ignored, parent_rule(matcher, path)}
    else
      direct_check(matcher, path, type)
    end
  end

  defp parent_excluded?(matcher, path) do
    path
    |> parent_paths()
    |> Enum.any?(fn parent ->
      case direct_check(matcher, parent, :directory) do
        {:ignored, %Rule{dir_only?: true}} -> true
        _other -> false
      end
    end)
  end

  defp parent_rule(matcher, path) do
    path
    |> parent_paths()
    |> Enum.find_value(fn parent ->
      case direct_check(matcher, parent, :directory) do
        {:ignored, %Rule{dir_only?: true} = rule} -> rule
        _other -> nil
      end
    end)
  end

  defp direct_check(matcher, path, type) do
    matcher.rules
    |> Enum.reverse()
    |> Enum.find(fn rule -> rule_matches?(matcher, rule, path, type) end)
    |> case do
      nil -> :not_ignored
      %Rule{negated?: true} = rule -> {:unignored, rule}
      %Rule{} = rule -> {:ignored, rule}
    end
  end

  defp rule_matches?(_matcher, %Rule{dir_only?: true}, _path, :file), do: false

  defp rule_matches?(matcher, %Rule{} = rule, path, type) do
    rule
    |> candidate_paths(path, type)
    |> Enum.any?(fn candidate ->
      Wildmatch.match?(rule.pattern, candidate, pathname: true, casefold: matcher.casefold?)
    end)
  end

  defp candidate_paths(%Rule{anchored?: true}, path, _type), do: [path]

  defp candidate_paths(%Rule{basename?: true}, path, type) do
    base = Path.basename(path)
    descendants = if type == :file, do: parent_paths(path), else: parent_paths(path) ++ [path]
    [base | descendants]
  end

  defp candidate_paths(_rule, path, _type), do: [path]

  defp parent_paths(path) do
    path
    |> String.split("/", trim: true)
    |> Enum.drop(-1)
    |> prefixes()
  end

  defp prefixes(parts) do
    parts
    |> Enum.scan([], fn part, acc -> acc ++ [part] end)
    |> Enum.map(&Enum.join(&1, "/"))
  end

  defp normalize_relative("./" <> rest), do: normalize_relative(rest)
  defp normalize_relative(path), do: String.trim(path, "/")
end
