defmodule Gitignore.Matcher do
  @moduledoc """
  Compiled matcher for one set of gitignore rules.

  Matchers are usually produced by `Gitignore.compile/2`.
  """

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

  @doc """
  Returns the matching rule for `path`, mirroring `git check-ignore -v`.

  Requires `type: :file | :directory`. Pass `parents: false` to skip the
  ancestor-directory walk; `Gitignore.Stack` does its own walk across all
  layered matchers.
  """
  @spec check(t(), binary(), keyword()) :: {:ignored | :unignored, Rule.t()} | :not_ignored
  def check(%__MODULE__{} = matcher, path, opts) when is_binary(path) do
    type = Keyword.fetch!(opts, :type)
    path = normalize_relative(path)

    with true <- Keyword.get(opts, :parents, true),
         {:ignored, rule} <- excluded_parent(matcher, path) do
      {:ignored, rule}
    else
      _no_excluded_parent -> direct_check(matcher, path, type)
    end
  end

  # A path inside an excluded directory is ignored no matter what later
  # rules say: git does not allow re-including anything under an excluded
  # parent, and reports the parent's rule.
  defp excluded_parent(matcher, path) do
    path
    |> parent_paths()
    |> Enum.find_value(:not_ignored, fn parent ->
      case direct_check(matcher, parent, :directory) do
        {:ignored, rule} -> {:ignored, rule}
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

  defp rule_matches?(matcher, %Rule{} = rule, path, _type) do
    candidate = if rule.basename?, do: Path.basename(path), else: path

    Wildmatch.match?(rule.pattern, candidate, pathname: true, casefold: matcher.casefold?)
  end

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
