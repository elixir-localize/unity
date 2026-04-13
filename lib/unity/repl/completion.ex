defmodule Unity.Repl.Completion do
  @moduledoc false

  # Tab completion for the Unity REPL. Provides completions for unit
  # names, aliases, function names, and REPL commands.
  #
  # The expand function follows the Erlang `edlin` expand_fun protocol:
  #   fun(ReversedChars) -> {yes | no, Expansion, Completions}

  @commands ~w(help bindings list search conformable info locale quit exit)

  @functions ~w(
    sqrt cbrt abs round ceil floor
    sin cos tan asin acos atan
    sinh cosh tanh asinh acosh atanh
    ln log log2 exp
    atan2 hypot gcd lcm min max mod factorial gamma
    now today datetime unixtime timestamp
    assert_eq
    unit_of value_of is_dimensionless
    increase_by decrease_by percentage_change
  )

  @doc false
  def expand(reverse_chars) do
    line = reverse_chars |> List.to_string() |> String.reverse()

    # Extract the word being typed (last whitespace-delimited token)
    word = line |> String.split(~r/[\s(,]+/) |> List.last() |> Kernel.||("")

    if word == "" do
      {:no, ~c"", []}
    else
      candidates = completions_for(word)

      case candidates do
        [] ->
          {:no, ~c"", []}

        [single] ->
          expansion = String.slice(single, String.length(word), String.length(single))
          {:yes, String.to_charlist(expansion), []}

        multiple ->
          common = common_prefix(multiple, word)
          expansion = String.slice(common, String.length(word), String.length(common))
          display = Enum.map(multiple, &String.to_charlist/1)
          {:yes, String.to_charlist(expansion), display}
      end
    end
  end

  defp completions_for(prefix) do
    all_names()
    |> Enum.filter(&String.starts_with?(&1, prefix))
    |> Enum.sort()
    |> Enum.take(50)
  end

  defp all_names do
    aliases = Unity.Aliases.all_known_names()
    custom = Localize.Unit.CustomRegistry.all() |> Map.keys()
    @commands ++ @functions ++ aliases ++ custom
  end

  defp common_prefix([first | rest], _seed) do
    Enum.reduce(rest, first, fn candidate, acc ->
      shared_prefix(acc, candidate)
    end)
  end

  defp shared_prefix(a, b) do
    a_chars = String.graphemes(a)
    b_chars = String.graphemes(b)

    a_chars
    |> Enum.zip(b_chars)
    |> Enum.take_while(fn {x, y} -> x == y end)
    |> Enum.map(&elem(&1, 0))
    |> Enum.join()
  end
end
