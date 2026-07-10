defmodule Gitignore.Wildmatch do
  @moduledoc """
  Wildmatch pattern matching used by gitignore rules.

  This module only matches one pattern against one path. It does not know about
  negation, directory-only rules, ignore-file ordering, or nested ignore files.

  Matching is byte-oriented, like git's wildmatch: `?` matches exactly one
  byte, and `casefold: true` folds ASCII letters only. Behavior is verified
  against the t3070 fixture suite extracted from git, including git's quirks:
  a malformed character class or a lone trailing backslash fails the whole
  match, and `**` is only special when it sits between slashes or pattern
  boundaries.
  """

  @type option :: {:pathname, boolean()} | {:casefold, boolean()}

  @posix_classes ~w(alnum alpha blank cntrl digit graph lower print punct space upper xdigit)

  @doc """
  Returns true when `pattern` matches `path`.

  In pathname mode, `?`, `*`, and character classes do not match `/`.
  """
  @spec match?(binary(), binary(), [option()]) :: boolean()
  def match?(pattern, path, opts \\ []) when is_binary(pattern) and is_binary(path) do
    pathname? = Keyword.get(opts, :pathname, true)
    casefold? = Keyword.get(opts, :casefold, false)

    dowild(pattern, path, nil, pathname?, casefold?) == :match
  end

  # Recursive matcher with git's four outcomes. `:abort_all` fails the whole
  # match (no backtracking); `:abort_to_starstar` unwinds to the nearest
  # slash-crossing star. `prev` is the previous pattern byte, needed to decide
  # whether `**` sits in a special position (pattern start or after a slash).

  defp dowild(<<>>, <<>>, _prev, _pathname?, _casefold?), do: :match
  defp dowild(<<>>, _text, _prev, _pathname?, _casefold?), do: :nomatch

  defp dowild(<<?*, after_star::binary>>, text, prev, pathname?, casefold?) do
    {double?, rest} = strip_stars(after_star, false)

    cond do
      not double? ->
        star_tail(rest, text, not pathname?, pathname?, casefold?)

      not pathname? ->
        star_tail(rest, text, true, pathname?, casefold?)

      special_globstar?(prev, rest) ->
        globstar(rest, text, pathname?, casefold?)

      true ->
        star_tail(rest, text, false, pathname?, casefold?)
    end
  end

  defp dowild(_pattern, <<>>, _prev, _pathname?, _casefold?), do: :abort_all

  defp dowild(<<??, _::binary>>, <<?/, _::binary>>, _prev, true, _casefold?), do: :nomatch

  defp dowild(<<??, rest::binary>>, <<_t_ch, t_rest::binary>>, _prev, pathname?, casefold?) do
    dowild(rest, t_rest, ??, pathname?, casefold?)
  end

  defp dowild(<<?\\, esc, rest::binary>>, <<t_ch, t_rest::binary>>, _prev, pathname?, casefold?) do
    # The escaped byte is compared verbatim; git does not casefold it.
    if fold(t_ch, casefold?) == esc do
      dowild(rest, t_rest, esc, pathname?, casefold?)
    else
      :nomatch
    end
  end

  defp dowild(<<?\\>>, _text, _prev, _pathname?, _casefold?), do: :nomatch

  defp dowild(<<?[, class::binary>>, <<t_ch, t_rest::binary>>, _prev, pathname?, casefold?) do
    case match_class(class, fold(t_ch, casefold?), casefold?) do
      :abort_all ->
        :abort_all

      {matched?, negated?, after_class} ->
        cond do
          matched? == negated? -> :nomatch
          pathname? and t_ch == ?/ -> :nomatch
          true -> dowild(after_class, t_rest, ?], pathname?, casefold?)
        end
    end
  end

  defp dowild(<<p_ch, rest::binary>>, <<t_ch, t_rest::binary>>, _prev, pathname?, casefold?) do
    if fold(p_ch, casefold?) == fold(t_ch, casefold?) do
      dowild(rest, t_rest, p_ch, pathname?, casefold?)
    else
      :nomatch
    end
  end

  # `**` is special only at the pattern start or after a slash, and only when
  # followed by end-of-pattern, a slash, or an escaped slash.
  defp special_globstar?(prev, rest) when prev in [nil, ?/] do
    case rest do
      <<>> -> true
      <<?/, _::binary>> -> true
      <<?\\, ?/, _::binary>> -> true
      _ -> false
    end
  end

  defp special_globstar?(_prev, _rest), do: false

  defp globstar(<<?/, after_slash::binary>> = rest, text, pathname?, casefold?) do
    # `**/` first tries to match zero directories, then falls back to a
    # slash-crossing star that requires at least one directory.
    case dowild(after_slash, text, nil, pathname?, casefold?) do
      :match -> :match
      _other -> star_tail(rest, text, true, pathname?, casefold?)
    end
  end

  defp globstar(rest, text, pathname?, casefold?) do
    star_tail(rest, text, true, pathname?, casefold?)
  end

  defp strip_stars(<<?*, rest::binary>>, _double?), do: strip_stars(rest, true)
  defp strip_stars(rest, double?), do: {double?, rest}

  # Trailing star: a slash-crossing star matches everything; a plain star
  # matches only when no directory separator remains.
  defp star_tail(<<>>, text, match_slash?, _pathname?, _casefold?) do
    if not match_slash? and contains_slash?(text) do
      :abort_to_starstar
    else
      :match
    end
  end

  # A plain star directly before a slash consumes exactly up to the next
  # slash in the text; there is nothing else it could match.
  defp star_tail(<<?/, rest::binary>>, text, false, pathname?, casefold?) do
    case skip_to_slash(text) do
      :none -> :abort_all
      after_slash -> dowild(rest, after_slash, ?/, pathname?, casefold?)
    end
  end

  defp star_tail(rest, text, match_slash?, pathname?, casefold?) do
    star_loop(rest, text, match_slash?, pathname?, casefold?)
  end

  # Tries the remaining pattern at each position the star could stop at.
  defp star_loop(rest, text, match_slash?, pathname?, casefold?) do
    case advance_to_literal(rest, text, match_slash?, casefold?) do
      abort when abort in [:abort_all, :abort_to_starstar] ->
        abort

      {:ok, <<>>} ->
        :abort_all

      {:ok, text} ->
        try_star_position(rest, text, match_slash?, pathname?, casefold?)
    end
  end

  defp try_star_position(
         rest,
         <<t_ch, t_rest::binary>> = text,
         match_slash?,
         pathname?,
         casefold?
       ) do
    case dowild(rest, text, ?*, pathname?, casefold?) do
      :nomatch when not match_slash? and t_ch == ?/ ->
        :abort_to_starstar

      :nomatch ->
        star_loop(rest, t_rest, match_slash?, pathname?, casefold?)

      :abort_to_starstar when match_slash? ->
        star_loop(rest, t_rest, match_slash?, pathname?, casefold?)

      result ->
        result
    end
  end

  # When the star is followed by a literal byte, every byte the star consumes
  # up to that literal is forced, so jump straight to it. Not finding it
  # fails this star for good: a slash-crossing star fails the whole match,
  # a plain star unwinds so an enclosing `**` can retry further along.
  defp advance_to_literal(<<p_ch, _::binary>>, text, match_slash?, casefold?)
       when p_ch not in [?*, ??, ?[, ?\\] do
    seek_byte(text, fold(p_ch, casefold?), match_slash?, casefold?)
  end

  defp advance_to_literal(_rest, text, _match_slash?, _casefold?), do: {:ok, text}

  defp seek_byte(<<>>, _target, match_slash?, _casefold?), do: seek_failure(match_slash?)

  defp seek_byte(<<?/, _::binary>>, target, false, _casefold?) when target != ?/,
    do: seek_failure(false)

  defp seek_byte(<<t_ch, t_rest::binary>> = text, target, match_slash?, casefold?) do
    if fold(t_ch, casefold?) == target do
      {:ok, text}
    else
      seek_byte(t_rest, target, match_slash?, casefold?)
    end
  end

  defp seek_failure(true), do: :abort_all
  defp seek_failure(false), do: :abort_to_starstar

  # Character classes.
  #
  # Returns {matched?, negated?, rest_after_class} or :abort_all for a
  # malformed class (unterminated, or an unknown POSIX class name).
  defp match_class(class, t_ch, casefold?) do
    {negated?, items} =
      case class do
        <<?!, rest::binary>> -> {true, rest}
        <<?^, rest::binary>> -> {true, rest}
        rest -> {false, rest}
      end

    case class_items(items, t_ch, casefold?, 0, false, true) do
      :abort_all -> :abort_all
      {matched?, after_class} -> {matched?, negated?, after_class}
    end
  end

  # Walks class items tracking the previous item byte (0 when the previous
  # construct was a range or POSIX class) and whether this is the first item,
  # since a leading `]` is a literal member rather than the terminator.

  defp class_items(<<>>, _t_ch, _casefold?, _prev, _matched?, _first?), do: :abort_all

  defp class_items(<<?], rest::binary>>, _t_ch, _casefold?, _prev, matched?, false),
    do: {matched?, rest}

  defp class_items(<<?\\, esc, rest::binary>>, t_ch, casefold?, _prev, matched?, _first?) do
    class_items(rest, t_ch, casefold?, esc, matched? or t_ch == esc, false)
  end

  defp class_items(<<?-, next, _::binary>> = items, t_ch, casefold?, prev, matched?, _first?)
       when prev != 0 and next != ?] do
    <<?-, rest::binary>> = items

    case range_endpoint(rest) do
      :abort_all ->
        :abort_all

      {hi, rest} ->
        matched? = matched? or in_range?(t_ch, prev, hi, casefold?)
        class_items(rest, t_ch, casefold?, 0, matched?, false)
    end
  end

  defp class_items(<<?[, ?:, rest::binary>>, t_ch, casefold?, _prev, matched?, _first?) do
    case posix_body(rest) do
      :abort_all ->
        :abort_all

      {:posix, name, after_class} ->
        if name in @posix_classes do
          matched? = matched? or posix_match?(name, t_ch, casefold?)
          class_items(after_class, t_ch, casefold?, 0, matched?, false)
        else
          :abort_all
        end

      :not_posix ->
        # Reinterpret the `[` as a plain member and continue from the `:`.
        class_items(<<?:, rest::binary>>, t_ch, casefold?, ?[, matched? or t_ch == ?[, false)
    end
  end

  defp class_items(<<item, rest::binary>>, t_ch, casefold?, _prev, matched?, _first?) do
    class_items(rest, t_ch, casefold?, item, matched? or t_ch == item, false)
  end

  defp range_endpoint(<<?\\, hi, rest::binary>>), do: {hi, rest}
  defp range_endpoint(<<?\\>>), do: :abort_all
  defp range_endpoint(<<hi, rest::binary>>), do: {hi, rest}

  # Range endpoints are compared verbatim; under casefold the folded text
  # byte gets a second chance as its uppercase counterpart.
  defp in_range?(t_ch, lo, hi, casefold?) do
    (t_ch >= lo and t_ch <= hi) or
      (casefold? and t_ch in ?a..?z and t_ch - 32 >= lo and t_ch - 32 <= hi)
  end

  # A POSIX class body is everything between `[:` and the next `]`, which
  # must end with `:` and name a known class. `[[:]` reads as plain members.
  defp posix_body(rest) do
    case :binary.match(rest, "]") do
      :nomatch ->
        :abort_all

      {pos, 1} ->
        content = binary_part(rest, 0, pos)
        after_class = binary_part(rest, pos + 1, byte_size(rest) - pos - 1)

        if byte_size(content) >= 1 and :binary.last(content) == ?: do
          {:posix, binary_part(content, 0, byte_size(content) - 1), after_class}
        else
          :not_posix
        end
    end
  end

  defp posix_match?("alnum", t, _cf), do: alpha?(t) or digit?(t)
  defp posix_match?("alpha", t, _cf), do: alpha?(t)
  defp posix_match?("blank", t, _cf), do: t in [?\t, ?\s]
  defp posix_match?("cntrl", t, _cf), do: t in 0..31 or t == 127
  defp posix_match?("digit", t, _cf), do: digit?(t)
  defp posix_match?("graph", t, _cf), do: t in 33..126
  defp posix_match?("lower", t, _cf), do: t in ?a..?z
  defp posix_match?("print", t, _cf), do: t in 32..126
  defp posix_match?("punct", t, _cf), do: t in 33..126 and not alpha?(t) and not digit?(t)
  defp posix_match?("space", t, _cf), do: t in [?\t, ?\n, ?\v, ?\f, ?\r, ?\s]
  defp posix_match?("upper", t, cf), do: t in ?A..?Z or (cf and t in ?a..?z)
  defp posix_match?("xdigit", t, _cf), do: digit?(t) or t in ?a..?f or t in ?A..?F

  defp alpha?(t), do: t in ?a..?z or t in ?A..?Z
  defp digit?(t), do: t in ?0..?9

  defp contains_slash?(text), do: :binary.match(text, "/") != :nomatch

  defp skip_to_slash(text) do
    case :binary.match(text, "/") do
      :nomatch -> :none
      {pos, 1} -> binary_part(text, pos + 1, byte_size(text) - pos - 1)
    end
  end

  defp fold(ch, true) when ch in ?A..?Z, do: ch + 32
  defp fold(ch, _casefold?), do: ch
end
