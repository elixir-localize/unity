defmodule Units.GnuUnitsImporter.Parser do
  @moduledoc """
  Pass 1: parses a GNU `units` definition file into raw data structures.

  Reads line by line, handling continuation lines, comments, directives,
  and different definition types. Produces a map suitable for the resolver.

  """

  @type parsed :: %{
          primitives: %{String.t() => :base | :dimensionless},
          prefixes: %{String.t() => String.t()},
          definitions: %{String.t() => String.t()},
          aliases: %{String.t() => String.t()},
          functions: %{String.t() => String.t()},
          skipped: [{String.t(), String.t()}]
        }

  @doc """
  Parses a GNU units definition file into raw data structures.

  ### Arguments

  * `path` — path to the definitions file.

  ### Returns

  * `{:ok, parsed}` with the parsed data.

  * `{:error, reason}` if the file cannot be read.

  """
  @spec parse_file(String.t()) :: {:ok, parsed()} | {:error, String.t()}
  def parse_file(path) do
    expanded = Path.expand(path)

    case File.read(expanded) do
      {:ok, content} ->
        {:ok, parse_content(content)}

      {:error, reason} ->
        {:error, "cannot read #{expanded}: #{reason}"}
    end
  end

  @doc """
  Parses GNU units definition content (as a string) into raw data structures.

  """
  @spec parse_content(String.t()) :: parsed()
  def parse_content(content) do
    state = %{
      primitives: %{},
      prefixes: %{},
      definitions: %{},
      aliases: %{},
      functions: %{},
      skipped: [],
      skip_depth: 0
    }

    content
    |> join_continuation_lines()
    |> String.split("\n")
    |> Enum.reduce(state, &parse_line/2)
    |> Map.delete(:skip_depth)
  end

  # ── Line processing ──

  defp parse_line(line, state) do
    line = strip_comment(line) |> String.trim()

    cond do
      line == "" ->
        state

      String.starts_with?(line, "!") ->
        handle_directive(line, state)

      state.skip_depth > 0 ->
        state

      true ->
        parse_definition(line, state)
    end
  end

  defp strip_comment(line) do
    case String.split(line, "#", parts: 2) do
      [before, _comment] -> before
      [line] -> line
    end
  end

  defp join_continuation_lines(content) do
    content
    |> String.replace(~r/\\\s*\n\s*/, " ")
  end

  # ── Directives ──

  defp handle_directive(line, state) do
    cond do
      String.starts_with?(line, "!var ") or String.starts_with?(line, "!varnot ") or
        String.starts_with?(line, "!locale ") or String.starts_with?(line, "!utf8") ->
        %{state | skip_depth: state.skip_depth + 1}

      String.starts_with?(line, "!endvar") or String.starts_with?(line, "!endlocale") or
          String.starts_with?(line, "!endutf8") ->
        %{state | skip_depth: max(state.skip_depth - 1, 0)}

      true ->
        # !include, !message, !unitlist, !set, !prompt — skip
        state
    end
  end

  # ── Definition parsing ──

  defp parse_definition(line, state) do
    case split_definition(line) do
      {name, expression} ->
        classify_definition(name, expression, state)

      :skip ->
        state
    end
  end

  defp split_definition(line) do
    # Split on first run of whitespace
    case Regex.run(~r/^(\S+)\s+(.+)$/, line) do
      [_, name, expression] -> {name, String.trim(expression)}
      nil -> :skip
    end
  end

  defp classify_definition(name, expression, state) do
    cond do
      # Function definition: name(x) ...
      String.contains?(name, "(") ->
        fn_name = String.split(name, "(") |> hd()
        %{state | functions: Map.put(state.functions, fn_name, expression)}

      # Prefix definition: name ends with -
      String.ends_with?(name, "-") ->
        prefix = String.trim_trailing(name, "-")
        %{state | prefixes: Map.put(state.prefixes, prefix, expression)}

      # Primitive unit: expression is ! or !dimensionless
      String.starts_with?(expression, "!") ->
        type = if expression == "!dimensionless", do: :dimensionless, else: :base
        %{state | primitives: Map.put(state.primitives, name, type)}

      # Single-word expression that doesn't contain numbers or operators → alias
      is_alias?(expression) ->
        %{state | aliases: Map.put(state.aliases, name, expression)}

      # Regular unit definition
      true ->
        %{state | definitions: Map.put(state.definitions, name, expression)}
    end
  end

  defp is_alias?(expression) do
    # An alias is a single identifier with no numbers, operators, spaces, or hyphens.
    # Must be purely alphabetic (no digits — "1e3" or "2^10" are not aliases).
    Regex.match?(~r/^[a-zA-Z_]+$/, expression)
  end
end
