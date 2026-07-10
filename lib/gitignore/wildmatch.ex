defmodule Gitignore.Wildmatch do
  @moduledoc """
  Wildmatch pattern matching used by gitignore rules.

  This module only matches one pattern against one path. It does not know about
  negation, directory-only rules, ignore-file ordering, or nested ignore files.
  """

  @type option :: {:pathname, boolean()} | {:casefold, boolean()}

  @posix_classes ~w(alnum alpha blank cntrl digit graph lower print punct space upper xdigit)

  @doc """
  Returns true when `pattern` matches `path`.

  In pathname mode, `?` and `*` do not match `/`.
  """
  @spec match?(binary(), binary(), [option()]) :: boolean()
  def match?(pattern, path, opts \\ []) when is_binary(pattern) and is_binary(path) do
    pathname? = Keyword.get(opts, :pathname, true)
    casefold? = Keyword.get(opts, :casefold, false)

    pattern
    |> tokenize()
    |> mark_globstars(pathname?)
    |> match_tokens?(split_path(path), pathname?, casefold?)
  end

  defp split_path(path), do: String.graphemes(path)

  defp tokenize(pattern) do
    pattern
    |> String.graphemes()
    |> do_tokenize([])
    |> Enum.reverse()
  end

  defp do_tokenize([], acc), do: acc
  defp do_tokenize(["\\", char | rest], acc), do: do_tokenize(rest, [{:literal, char} | acc])
  defp do_tokenize(["?" | rest], acc), do: do_tokenize(rest, [:question | acc])
  defp do_tokenize(["*" | rest], acc), do: do_tokenize(rest, [:star | acc])

  defp do_tokenize(["[" | rest], acc) do
    case take_class(rest, []) do
      {:ok, class, tail} -> do_tokenize(tail, [{:class, class} | acc])
      :error -> do_tokenize(rest, [{:literal, "["} | acc])
    end
  end

  defp do_tokenize([char | rest], acc), do: do_tokenize(rest, [{:literal, char} | acc])

  defp take_class([], _acc), do: :error
  defp take_class(["]" | rest], []), do: take_class(rest, ["]"])

  defp take_class(["]" | rest], acc) do
    if posix_class_open?(acc) do
      take_class(rest, ["]" | acc])
    else
      {:ok, Enum.reverse(acc), rest}
    end
  end

  defp take_class([char | rest], acc), do: take_class(rest, [char | acc])

  defp posix_class_open?(acc) do
    reversed = Enum.reverse(acc)

    case reversed do
      ["[", ":" | _rest] -> not Enum.member?(reversed, "]")
      _other -> false
    end
  end

  defp mark_globstars(tokens, false), do: tokens

  defp mark_globstars(tokens, true) do
    tokens
    |> mark_leading_globstar()
    |> mark_trailing_globstar()
    |> mark_middle_globstars()
  end

  defp mark_leading_globstar([:star, :star, {:literal, "/"} | rest]),
    do: [:globstar_leading | rest]

  defp mark_leading_globstar(tokens), do: tokens

  defp mark_trailing_globstar(tokens) do
    case Enum.reverse(tokens) do
      [:star, :star, {:literal, "/"} | reversed_rest] ->
        Enum.reverse([:globstar_trailing | reversed_rest])

      _other ->
        tokens
    end
  end

  defp mark_middle_globstars([{:literal, "/"}, :star, :star, {:literal, "/"} | rest]) do
    [:globstar_middle | mark_middle_globstars(rest)]
  end

  defp mark_middle_globstars([token | rest]), do: [token | mark_middle_globstars(rest)]
  defp mark_middle_globstars([]), do: []

  defp match_tokens?([], [], _pathname?, _casefold?), do: true
  defp match_tokens?([], _path, _pathname?, _casefold?), do: false

  defp match_tokens?([:globstar_leading | rest], path, pathname?, casefold?) do
    match_tokens?(rest, path, pathname?, casefold?) or
      consume_until_match(rest, path, pathname?, casefold?)
  end

  defp match_tokens?([:globstar_middle | rest], path, pathname?, casefold?) do
    match_tokens?(rest, path, pathname?, casefold?) or
      consume_until_match(rest, path, pathname?, casefold?)
  end

  defp match_tokens?([:globstar_trailing], _path, _pathname?, _casefold?), do: true
  defp match_tokens?([:question | _rest], ["/" | _path_rest], true, _casefold?), do: false

  defp match_tokens?([:question | rest], [_char | path_rest], pathname?, casefold?) do
    match_tokens?(rest, path_rest, pathname?, casefold?)
  end

  defp match_tokens?([:star | rest], path, pathname?, casefold?) do
    match_star?(rest, path, pathname?, casefold?)
  end

  defp match_tokens?([{:class, _class} | _rest], ["/" | _path_rest], true, _casefold?), do: false

  defp match_tokens?([{:class, class} | rest], [char | path_rest], pathname?, casefold?) do
    class_match?(class, char, casefold?) and match_tokens?(rest, path_rest, pathname?, casefold?)
  end

  defp match_tokens?(
         [{:literal, pattern_char} | rest],
         [path_char | path_rest],
         pathname?,
         casefold?
       ) do
    char_equal?(pattern_char, path_char, casefold?) and
      match_tokens?(rest, path_rest, pathname?, casefold?)
  end

  defp match_tokens?(_tokens, _path, _pathname?, _casefold?), do: false

  defp match_star?(rest, path, pathname?, casefold?) do
    match_tokens?(rest, path, pathname?, casefold?) or
      consume_star?(rest, path, pathname?, casefold?)
  end

  defp consume_star?(_rest, [], _pathname?, _casefold?), do: false
  defp consume_star?(_rest, ["/" | _path_rest], true, _casefold?), do: false

  defp consume_star?(rest, [_char | path_rest], pathname?, casefold?) do
    match_star?(rest, path_rest, pathname?, casefold?)
  end

  defp consume_until_match(_rest, [], _pathname?, _casefold?), do: false

  defp consume_until_match(rest, [_char | path_rest] = path, pathname?, casefold?) do
    match_tokens?(rest, path_rest, pathname?, casefold?) or
      consume_until_match(rest, path_rest, pathname?, casefold?) or
      match_tokens?(rest, path, pathname?, casefold?)
  end

  defp class_match?(class, char, casefold?) do
    {negated?, items} =
      case class do
        ["!" | rest] -> {true, rest}
        ["^" | rest] -> {true, rest}
        rest -> {false, rest}
      end

    matched? = class_items_match?(items, char, casefold?)
    if negated?, do: not matched?, else: matched?
  end

  defp class_items_match?([], _char, _casefold?), do: false

  defp class_items_match?(["[", ":" | rest], char, casefold?) do
    case take_posix_class(rest, []) do
      {:ok, class_name, tail} when class_name in @posix_classes ->
        posix_class_match?(class_name, char) or class_items_match?(tail, char, casefold?)

      _other ->
        class_items_match?(rest, char, casefold?) or char_equal?("[", char, casefold?)
    end
  end

  defp class_items_match?([left, "-", right | rest], char, casefold?) when right != "]" do
    char_in_range?(left, right, char, casefold?) or class_items_match?(rest, char, casefold?)
  end

  defp class_items_match?([item | rest], char, casefold?) do
    char_equal?(item, char, casefold?) or class_items_match?(rest, char, casefold?)
  end

  defp take_posix_class([":", "]" | rest], acc),
    do: {:ok, acc |> Enum.reverse() |> Enum.join(), rest}

  defp take_posix_class([], _acc), do: :error
  defp take_posix_class([char | rest], acc), do: take_posix_class(rest, [char | acc])

  defp posix_class_match?("alnum", char), do: ascii_alpha?(char) or ascii_digit?(char)
  defp posix_class_match?("alpha", char), do: ascii_alpha?(char)
  defp posix_class_match?("blank", char), do: char in ["\t", " "]
  defp posix_class_match?("cntrl", <<char>>), do: char in 0..31 or char == 127
  defp posix_class_match?("cntrl", _char), do: false
  defp posix_class_match?("digit", char), do: ascii_digit?(char)
  defp posix_class_match?("graph", <<char>>), do: char in 33..126
  defp posix_class_match?("graph", _char), do: false
  defp posix_class_match?("lower", <<char>>), do: char in ?a..?z
  defp posix_class_match?("lower", _char), do: false
  defp posix_class_match?("print", <<char>>), do: char in 32..126
  defp posix_class_match?("print", _char), do: false

  defp posix_class_match?("punct", <<char>>),
    do: char in 33..47 or char in 58..64 or char in 91..96 or char in 123..126

  defp posix_class_match?("punct", _char), do: false
  defp posix_class_match?("space", char), do: char in ["\t", "\n", "\v", "\f", "\r", " "]
  defp posix_class_match?("upper", <<char>>), do: char in ?A..?Z
  defp posix_class_match?("upper", _char), do: false

  defp posix_class_match?("xdigit", char),
    do: ascii_digit?(char) or char in ~w(a b c d e f A B C D E F)

  defp char_in_range?(left, right, char, false), do: left <= char and char <= right

  defp char_in_range?(left, right, char, true) do
    left = downcase_ascii(left)
    right = downcase_ascii(right)
    char = downcase_ascii(char)

    left <= char and char <= right
  end

  defp char_equal?(left, right, false), do: left == right

  defp char_equal?(left, right, true) do
    downcase_ascii(left) == downcase_ascii(right)
  end

  defp ascii_alpha?(<<char>>), do: char in ?a..?z or char in ?A..?Z
  defp ascii_alpha?(_char), do: false

  defp ascii_digit?(<<char>>), do: char in ?0..?9
  defp ascii_digit?(_char), do: false

  defp downcase_ascii(<<char>>) when char in ?A..?Z, do: <<char + 32>>
  defp downcase_ascii(char), do: char
end
