defmodule Unity.Repl.Markdown do
  @moduledoc false

  # Renders markdown to terminal output via Marcli, with TTY/no-color awareness.
  # When coloring is disabled, ANSI escape sequences are stripped.

  alias Unity.Repl.Color

  @doc """
  Renders a markdown string to terminal output.

  ANSI escape sequences are emitted only when `Unity.Repl.Color.enabled?/0`
  returns true. Otherwise plain text is produced.
  """
  @spec render(String.t()) :: String.t()
  def render(markdown) when is_binary(markdown) do
    Marcli.render(markdown, escape_sequences: Color.enabled?())
  end
end
