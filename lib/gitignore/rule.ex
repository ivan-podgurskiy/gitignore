defmodule Gitignore.Rule do
  @moduledoc """
  Parsed gitignore rule metadata.

  Rules are usually produced by `Gitignore.parse/1` rather than constructed
  directly.
  """

  defstruct [
    :pattern,
    :source,
    :line,
    negated?: false,
    dir_only?: false,
    anchored?: false,
    basename?: false
  ]

  @type t :: %__MODULE__{
          pattern: binary(),
          source: binary(),
          line: pos_integer(),
          negated?: boolean(),
          dir_only?: boolean(),
          anchored?: boolean(),
          basename?: boolean()
        }

  @spec parse(binary(), pos_integer()) :: {:ok, t()} | :skip
  def parse(line, line_number)
      when is_binary(line) and is_integer(line_number) and line_number > 0 do
    source = line |> String.trim_trailing("\n") |> String.trim_trailing("\r")
    stripped = trim_unescaped_trailing_spaces(source)

    cond do
      stripped == "" -> :skip
      String.starts_with?(stripped, "#") -> :skip
      true -> {:ok, build_rule(stripped, source, line_number)}
    end
  end

  defp build_rule(line, source, line_number) do
    {negated?, body} = negation(line)
    unescaped = unescape_leading(body)
    {dir_only?, without_dir_suffix} = dir_only(unescaped)
    {anchored?, pattern} = anchoring(without_dir_suffix)

    %__MODULE__{
      pattern: pattern,
      source: source,
      line: line_number,
      negated?: negated?,
      dir_only?: dir_only?,
      anchored?: anchored?,
      basename?: not anchored? and not String.contains?(pattern, "/")
    }
  end

  defp negation("!" <> rest), do: {true, rest}
  defp negation(line), do: {false, line}

  defp unescape_leading("\\!" <> rest), do: "!" <> rest
  defp unescape_leading("\\#" <> rest), do: "#" <> rest
  defp unescape_leading(line), do: String.replace(line, "\\ ", " ")

  defp dir_only(pattern) do
    if String.ends_with?(pattern, "/") do
      {true, String.trim_trailing(pattern, "/")}
    else
      {false, pattern}
    end
  end

  defp anchoring("/" <> rest), do: {true, rest}

  defp anchoring(pattern) do
    {String.contains?(pattern, "/"), pattern}
  end

  defp trim_unescaped_trailing_spaces(line) do
    line
    |> String.graphemes()
    |> Enum.reverse()
    |> trim_reversed_trailing_spaces([])
    |> Enum.join()
  end

  defp trim_reversed_trailing_spaces([], acc), do: acc

  defp trim_reversed_trailing_spaces([" ", "\\" | rest], acc),
    do: Enum.reverse(rest) ++ ["\\", " " | acc]

  defp trim_reversed_trailing_spaces([" " | rest], acc),
    do: trim_reversed_trailing_spaces(rest, acc)

  defp trim_reversed_trailing_spaces(rest, acc), do: Enum.reverse(rest) ++ acc
end
