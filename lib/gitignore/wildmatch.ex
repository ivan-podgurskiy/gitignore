defmodule Gitignore.Wildmatch do
  @moduledoc """
  Wildmatch pattern matching used by gitignore rules.

  This module only matches one pattern against one path. It does not know about
  negation, directory-only rules, ignore-file ordering, or nested ignore files.
  """

  @type option :: {:pathname, boolean()} | {:casefold, boolean()}

  @doc """
  Returns true when `pattern` matches `path`.

  In pathname mode, `?` and `*` do not match `/`.
  """
  @spec match?(binary(), binary(), [option()]) :: boolean()
  def match?(pattern, path, opts \\ []) when is_binary(pattern) and is_binary(path) do
    pathname? = Keyword.get(opts, :pathname, true)
    casefold? = Keyword.get(opts, :casefold, false)

    do_match?(pattern, path, pathname?, casefold?)
  end

  defp do_match?(<<>>, <<>>, _pathname?, _casefold?), do: true
  defp do_match?(<<>>, _path, _pathname?, _casefold?), do: false

  defp do_match?(
         <<"\\", escaped::utf8, rest::binary>>,
         <<char::utf8, path_rest::binary>>,
         pathname?,
         casefold?
       ) do
    char_equal?(escaped, char, casefold?) and do_match?(rest, path_rest, pathname?, casefold?)
  end

  defp do_match?(<<"?", _rest::binary>>, <<"/", _path_rest::binary>>, true, _casefold?),
    do: false

  defp do_match?(<<"?", rest::binary>>, <<_char::utf8, path_rest::binary>>, pathname?, casefold?) do
    do_match?(rest, path_rest, pathname?, casefold?)
  end

  defp do_match?(<<"*", rest::binary>>, path, pathname?, casefold?) do
    match_star?(rest, path, pathname?, casefold?)
  end

  defp do_match?(
         <<pattern_char::utf8, rest::binary>>,
         <<path_char::utf8, path_rest::binary>>,
         pathname?,
         casefold?
       ) do
    char_equal?(pattern_char, path_char, casefold?) and
      do_match?(rest, path_rest, pathname?, casefold?)
  end

  defp do_match?(_pattern, _path, _pathname?, _casefold?), do: false

  defp match_star?(rest, path, pathname?, casefold?) do
    do_match?(rest, path, pathname?, casefold?) or consume_star?(rest, path, pathname?, casefold?)
  end

  defp consume_star?(_rest, <<>>, _pathname?, _casefold?), do: false
  defp consume_star?(_rest, <<"/", _path_rest::binary>>, true, _casefold?), do: false

  defp consume_star?(rest, <<_char::utf8, path_rest::binary>>, pathname?, casefold?) do
    match_star?(rest, path_rest, pathname?, casefold?)
  end

  defp char_equal?(left, right, false), do: left == right

  defp char_equal?(left, right, true) do
    downcase_ascii(left) == downcase_ascii(right)
  end

  defp downcase_ascii(char) when char in ?A..?Z, do: char + 32
  defp downcase_ascii(char), do: char
end
