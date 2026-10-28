defmodule Unity.ReplTest do
  @moduledoc """
  Covers deciding whether standard input is a terminal, which chooses
  between the REPL and reading expressions from standard input. The
  answers are those the Erlang terminal driver gives `:io.getopts/1`
  under `-noshell`, as in an escript, where `:echo` is false even on a
  terminal.

  """

  use ExUnit.Case, async: true

  # An I/O device that answers `:io.getopts/1` with `reply`.
  defp device(reply) do
    spawn_link(fn -> serve(reply) end)
  end

  defp serve(reply) do
    receive do
      {:io_request, from, reply_as, :getopts} ->
        send(from, {:io_reply, reply_as, reply})
        serve(reply)
    end
  end

  defp terminal_with(reply) do
    device = device(reply)
    parent = self()

    spawn_link(fn ->
      Process.group_leader(self(), device)
      send(parent, {:terminal?, Unity.Repl.terminal?()})
    end)

    receive do
      {:terminal?, answer} -> answer
    end
  end

  describe "terminal?/0" do
    test "is true for standard input on a terminal, echo notwithstanding" do
      assert terminal_with(echo: false, terminal: true, stdout: true, stdin: true)
    end

    test "is false for standard input from a pipe" do
      refute terminal_with(echo: false, terminal: true, stdout: true, stdin: false)
    end

    test "follows :terminal on OTP 26, which reports nothing else" do
      assert terminal_with(echo: false, terminal: true)
      refute terminal_with(echo: false, terminal: false)
    end

    test "is false for a device without terminal options, or one that fails" do
      refute terminal_with(binary: true, encoding: :unicode)
      refute terminal_with({:error, :enotsup})
    end
  end
end
