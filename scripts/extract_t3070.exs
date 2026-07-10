# Extracts wildmatch test cases from git's t/t3070-wildmatch.sh into
# test/fixtures/wildmatch_cases.exs.
#
# Usage:
#
#     mix run scripts/extract_t3070.exs            # uses the pinned ref below
#     mix run scripts/extract_t3070.exs v2.50.0    # refresh against another ref
#     mix run scripts/extract_t3070.exs path/to/t3070-wildmatch.sh
#
# The parser is deliberately strict: any `match` line it cannot parse with
# full confidence raises instead of guessing, so a git-side format change
# cannot silently corrupt expected values. Review the fixture diff on refresh.
defmodule ExtractT3070 do
  @default_ref "v2.48.1"
  @fixture_path "test/fixtures/wildmatch_cases.exs"

  # t3070 mode -> Gitignore.Wildmatch options. Order matches the first four
  # arguments of t3070's match() function.
  @modes [
    {"wildmatch", [pathname: true, casefold: false]},
    {"iwildmatch", [pathname: true, casefold: true]},
    {"pathmatch", [pathname: false, casefold: false]},
    {"ipathmatch", [pathname: false, casefold: true]}
  ]

  def run(args) do
    {source, ref} = source_and_ref(args)
    {script, origin} = fetch(source, ref)

    cases =
      script
      |> join_continuations()
      |> extract_cases()

    if cases == [], do: raise("no match cases extracted from #{origin}")

    File.write!(@fixture_path, render(cases, origin, ref))
    {_, 0} = System.cmd("mix", ["format", @fixture_path])
    IO.puts("wrote #{length(cases)} cases to #{@fixture_path} (source: #{origin})")
  end

  defp source_and_ref([]), do: {:remote, @default_ref}

  defp source_and_ref([arg]) do
    if File.regular?(arg), do: {{:file, arg}, "local file"}, else: {:remote, arg}
  end

  defp fetch({:file, path}, _ref), do: {File.read!(path), path}

  defp fetch(:remote, ref) do
    url = "https://raw.githubusercontent.com/git/git/#{ref}/t/t3070-wildmatch.sh"

    case System.cmd("curl", ["-sfL", url]) do
      {body, 0} -> {body, url}
      {_, status} -> raise "curl failed with status #{status} for #{url}"
    end
  end

  # Joins shell backslash-newline continuations, preserving the line number
  # of the first physical line of each command.
  defp join_continuations(script) do
    script
    |> String.split("\n")
    |> Enum.with_index(1)
    |> Enum.reduce([], fn {line, number}, acc ->
      case acc do
        [{prev, prev_number, true} | rest] ->
          joined = String.slice(prev, 0..-2//1) <> " " <> line
          [{joined, prev_number, String.ends_with?(line, "\\")} | rest]

        _ ->
          [{line, number, String.ends_with?(line, "\\")} | acc]
      end
    end)
    |> Enum.reverse()
    |> Enum.map(fn {line, number, _cont?} -> {line, number} end)
  end

  defp extract_cases(numbered_lines) do
    numbered_lines
    |> Enum.filter(fn {line, _n} -> String.starts_with?(line, "match ") end)
    |> Enum.flat_map(fn {line, number} -> line |> parse_match(number) |> cases_for(number) end)
  end

  defp parse_match(line, number) do
    words = split_words(line, number)

    case words do
      ["match", g, ig, p, ip, text, pattern] ->
        {[g, ig, p, ip], text, pattern}

      ["match", g, ig, p, ip, _fg, _fig, _fp, _fip, text, pattern] ->
        {[g, ig, p, ip], text, pattern}

      other ->
        raise "line #{number}: expected 6 or 10 match arguments, got #{length(other) - 1}: #{inspect(other)}"
    end
  end

  defp cases_for({expectations, text, pattern}, number) do
    @modes
    |> Enum.zip(expectations)
    |> Enum.map(fn {{mode, opts}, expectation} ->
      expected =
        case expectation do
          "1" -> true
          "0" -> false
          other -> raise "line #{number}: unexpected match value #{inspect(other)}"
        end

      %{
        name: "t3070 L#{number} #{mode}: #{inspect(pattern)} vs #{inspect(text)}",
        pattern: pattern,
        path: text,
        opts: opts,
        expected: expected
      }
    end)
  end

  # Minimal shell word splitter for t3070 match lines: bare words,
  # single-quoted strings (backslashes literal), and double-quoted strings
  # without escapes. Anything else raises.
  defp split_words(line, number) do
    line
    |> String.graphemes()
    |> do_split(:plain, nil, [], number)
    |> Enum.reverse()
  end

  defp do_split([], :plain, current, words, _number), do: finish_word(current, words)

  defp do_split([], state, _current, _words, number),
    do: raise("line #{number}: unterminated #{state} quote")

  defp do_split([char | rest], :plain, current, words, number) do
    case char do
      c when c in [" ", "\t"] -> do_split(rest, :plain, nil, finish_word(current, words), number)
      "'" -> do_split(rest, :single, current || "", words, number)
      "\"" -> do_split(rest, :double, current || "", words, number)
      "\\" -> raise "line #{number}: unsupported bare backslash outside quotes"
      c -> do_split(rest, :plain, (current || "") <> c, words, number)
    end
  end

  defp do_split([char | rest], :single, current, words, number) do
    case char do
      "'" -> do_split(rest, :plain, current, words, number)
      c -> do_split(rest, :single, current <> c, words, number)
    end
  end

  defp do_split([char | rest], :double, current, words, number) do
    case char do
      "\"" -> do_split(rest, :plain, current, words, number)
      "\\" -> raise "line #{number}: unsupported backslash inside double quotes"
      c -> do_split(rest, :double, current <> c, words, number)
    end
  end

  defp finish_word(nil, words), do: words
  defp finish_word(current, words), do: [current | words]

  defp render(cases, origin, ref) do
    entries =
      Enum.map_join(cases, ",\n", fn c ->
        """
        %{
          name: #{inspect(c.name)},
          pattern: #{inspect(c.pattern)},
          path: #{inspect(c.path)},
          opts: #{inspect(c.opts)},
          expected: #{c.expected}
        }\
        """
      end)

    """
    # Generated by scripts/extract_t3070.exs. DO NOT EDIT BY HAND.
    #
    # Source: #{origin}
    # Git ref: #{ref}
    # Cases: #{length(cases)} (#{div(length(cases), 4)} match lines x 4 modes)
    #
    # Modes map to Gitignore.Wildmatch options:
    #   wildmatch   -> pathname: true,  casefold: false
    #   iwildmatch  -> pathname: true,  casefold: true
    #   pathmatch   -> pathname: false, casefold: false
    #   ipathmatch  -> pathname: false, casefold: true
    #
    # Refresh: mix run scripts/extract_t3070.exs [ref] and review the diff.
    [
    #{entries}
    ]
    """
  end
end

ExtractT3070.run(System.argv())
