defmodule Unity.Repl.Markdown do
  @moduledoc false

  # Renders markdown to terminal output via Marcli when available.
  # Marcli is an optional dependency (it pulls in a Rust NIF via mdex).
  # When marcli is not present, falls back to a plain-text rendering that
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
      apply(Marcli, :render, [markdown, [escape_sequences: Color.enabled?()]])
    else
      plain_render(markdown)
    end
  end

  @doc "Returns true if Marcli is loaded and available."
  @spec marcli_available?() :: boolean()
  def marcli_available? do
    Code.ensure_loaded?(Marcli)
  end

  # ── Fallback plain renderer ──────────────────────────────────────
  #
  # Strips inline emphasis and code markers (`**bold**`, `*italic*`,
  # `` `code` ``) and renders headings as plain underlined text.
  # Tables are passed through as-is — they're already readable in
  # source form. Lists keep their bullets.

  defp plain_render(markdown) do
    markdown
    |> String.split("\n")
    |> Enum.map(&render_line/1)
    |> Enum.join("\n")
  end

  defp render_line("# " <> rest), do: Color.bold(strip_inline(rest))
  defp render_line("## " <> rest), do: Color.bold(strip_inline(rest))
  defp render_line("### " <> rest), do: Color.bold(strip_inline(rest))
  defp render_line("- " <> rest), do: "  • " <> strip_inline(rest)
  defp render_line("* " <> rest), do: "  • " <> strip_inline(rest)
  defp render_line(line), do: strip_inline(line)

  # Strip inline markdown markers, leaving the visible text. Backtick
  # code spans are preserved with dim styling (when colors enabled).
  defp strip_inline(text) do
    text
    |> replace_pattern(~r/\*\*(.+?)\*\*/, &Color.bold/1)
    |> replace_pattern(~r/(?<!\*)\*([^*]+)\*(?!\*)/, &Color.italic/1)
    |> replace_pattern(~r/`([^`]+)`/, &Color.dim/1)
  end

  defp replace_pattern(text, regex, formatter) do
    Regex.replace(regex, text, fn _full, inner -> formatter.(inner) end)
  end
end
