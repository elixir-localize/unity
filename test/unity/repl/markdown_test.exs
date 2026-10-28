defmodule Unity.Repl.MarkdownTest do
  @moduledoc """
  Covers the plain-text rendering the REPL falls back to without Marcli,
  as in an escript. Colour is off under `mix test`, so styling leaves the
  text unchanged.

  """

  use ExUnit.Case, async: true

  alias Unity.Repl.Markdown

  defp spaces(count), do: String.duplicate(" ", count)

  test "a table is laid out in columns, without its separator row" do
    markdown = """
    | Syntax | Description |
    |---|---|
    | `3 meters to feet` | Convert between units |
    | `1\\|3 cup` | Rational numbers |
    """

    # The first column is as wide as "3 meters to feet", 16 characters,
    # and columns are two spaces apart.
    assert Markdown.render_plain(markdown) ==
             Enum.join(
               [
                 "  Syntax" <> spaces(12) <> "Description",
                 "  3 meters to feet" <> spaces(2) <> "Convert between units",
                 "  1|3 cup" <> spaces(11) <> "Rational numbers",
                 ""
               ],
               "\n"
             )
  end

  test "a row with fewer cells is padded" do
    markdown = "| Name | Value |\n|---|---|\n| `x` |"

    assert Markdown.render_plain(markdown) ==
             "  Name" <> spaces(2) <> "Value\n  x"
  end

  test "a table with no rows but its separator renders as nothing" do
    assert Markdown.render_plain("|---|---|") == ""
  end

  test "headings, bullets and inline markers render as plain text" do
    markdown = "## Functions\n\n- **Unit:** `sqrt`, `abs`\n* *Trig:* `sin`"

    assert Markdown.render_plain(markdown) ==
             "Functions\n\n  • Unit: sqrt, abs\n  • Trig: sin"
  end
end
