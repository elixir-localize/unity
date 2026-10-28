defmodule Unity.Repl.Markdown do
  @moduledoc false

  # Renders markdown to terminal output via Marcli when available.
  # Marcli is an optional, development-only dependency (it pulls in a Rust
  # NIF via mdex): a project that depends on unity, or unity's own `:prod`
  # build and escript, has it only when it adds it. When marcli is absent,
  # or its NIF cannot load, falls back to a plain-text rendering that
  # strips most markdown decoration but preserves readability.

  alias Unity.Repl.Color

  @doc """
  Renders a markdown string to terminal output.

  Uses Marcli when available; otherwise produces a simple plain-text
  rendering. ANSI escape sequences are emitted only when
  `Unity.Repl.Color.enabled?/0` returns true.
  """
  @spec render(String.t()) :: String.t()
  def render(markdown) when is_binary(markdown) do
    if marcli_available?() do
      # Marcli is an optional dependency; a direct call would not compile
      # when it is absent, so dispatch stays dynamic behind the guard.
      # credo:disable-for-next-line Credo.Check.Refactor.Apply
      apply(Marcli, :render, [markdown, [escape_sequences: Color.enabled?()]])
    else
      render_plain(markdown)
    end
  end

  @doc "Returns true if Marcli is loaded and its native code can load."
  @spec marcli_available?() :: boolean()
  def marcli_available? do
    Code.ensure_loaded?(Marcli) and native_code_loadable?()
  end

  # Marcli renders through MDEx, whose Rust NIF is a shared library in the
  # `mdex_native` application's `priv` directory. A shared library loads
  # only from a file, so inside an escript, whose applications live in its
  # archive, the NIF cannot load and a render would crash. The directory is
  # checked rather than the module loaded, since a failed load logs a
  # warning into the session.
  defp native_code_loadable? do
    case :code.priv_dir(:mdex_native) do
      {:error, :bad_name} -> false
      priv -> File.dir?(priv)
    end
  end

  # ── Fallback plain renderer ──────────────────────────────────────
  #
  # Strips inline emphasis and code markers (`**bold**`, `*italic*`,
  # `` `code` ``) and renders headings as plain bold text. Tables are
  # laid out in columns padded to their widest cell, without the
  # separator row and with the header in bold. Lists keep their bullets.

  @doc false
  @spec render_plain(String.t()) :: String.t()
  def render_plain(markdown) do
    markdown
    |> String.split("\n")
    |> Enum.chunk_by(&table_row?/1)
    |> Enum.map_join("\n", &render_block/1)
  end

  defp render_block([first | _] = lines) do
    if table_row?(first),
      do: render_table(lines),
      else: Enum.map_join(lines, "\n", &render_line/1)
  end

  defp render_line("# " <> rest), do: Color.bold(strip_inline(rest))
  defp render_line("## " <> rest), do: Color.bold(strip_inline(rest))
  defp render_line("### " <> rest), do: Color.bold(strip_inline(rest))
  defp render_line("- " <> rest), do: "  • " <> strip_inline(rest)
  defp render_line("* " <> rest), do: "  • " <> strip_inline(rest)
  defp render_line(line), do: strip_inline(line)

  defp table_row?(line), do: String.starts_with?(String.trim_leading(line), "|")

  # Column widths are measured on the visible text, before styling adds
  # escape sequences.
  defp render_table(lines) do
    case lines |> Enum.map(&table_cells/1) |> Enum.reject(&separator_row?/1) do
      [] ->
        ""

      rows ->
        columns = rows |> Enum.map(&length/1) |> Enum.max()
        [header | body] = Enum.map(rows, &(&1 ++ List.duplicate("", columns - length(&1))))
        widths = column_widths([header | body])

        [
          table_line(header, widths, &Color.bold(visible_text(&1)))
          | Enum.map(body, &table_line(&1, widths, fn cell -> strip_inline(cell) end))
        ]
        |> Enum.join("\n")
    end
  end

  defp column_widths(rows) do
    rows
    |> Enum.zip_with(& &1)
    |> Enum.map(fn column ->
      column |> Enum.map(&String.length(visible_text(&1))) |> Enum.max()
    end)
  end

  defp table_line(cells, widths, style) do
    cells
    |> Enum.zip(widths)
    |> Enum.map_join("  ", fn {cell, width} ->
      style.(cell) <> String.duplicate(" ", width - String.length(visible_text(cell)))
    end)
    |> String.trim_trailing()
    |> then(&("  " <> &1))
  end

  # A cell boundary is a `|` not escaped as `\|`, which stands for a pipe
  # within the cell.
  defp table_cells(line) do
    line
    |> String.trim()
    |> String.replace(~r/\A\||(?<!\\)\|\z/, "")
    |> String.split(~r/(?<!\\)\|/)
    |> Enum.map(&(&1 |> String.trim() |> String.replace("\\|", "|")))
  end

  defp separator_row?(cells), do: Enum.all?(cells, &Regex.match?(~r/\A:?-+:?\z/, &1))

  # Strip inline markdown markers, leaving the visible text. Backtick
  # code spans are preserved with dim styling (when colors enabled).
  defp strip_inline(text), do: inline(text, &Color.bold/1, &Color.italic/1, &Color.dim/1)

  defp visible_text(text), do: inline(text, & &1, & &1, & &1)

  defp inline(text, bold, italic, code) do
    text
    |> replace_pattern(~r/\*\*(.+?)\*\*/, bold)
    |> replace_pattern(~r/(?<!\*)\*([^*]+)\*(?!\*)/, italic)
    |> replace_pattern(~r/`([^`]+)`/, code)
  end

  defp replace_pattern(text, regex, formatter) do
    Regex.replace(regex, text, fn _full, inner -> formatter.(inner) end)
  end
end
