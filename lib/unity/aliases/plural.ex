defmodule Unity.Aliases.Plural do
  @moduledoc """
  English pluralisation, singularisation and spelling-variant rules for CLDR
  unit names.

  `Unity.Aliases` uses this module in two places. At compile time it calls
  `plural/1` for every known CLDR unit to derive a plural alias, so that every
  unit which resolves in the singular also resolves in the plural. At run time
  it calls `candidates/1` to normalise a form that is not in the derived table
  — an SI-prefixed unit such as `milliseconds`, whose singular is assembled by
  `Localize.Unit` rather than enumerated, or a British spelling such as
  `millilitres`.

  The rules are deliberately closed. `candidates/1` only proposes alternative
  spellings; the caller must confirm each one is a real unit before accepting
  it. Nothing here promotes an arbitrary word to a unit, and in particular
  there is no "strip a trailing s and hope" fallback — `bricks` proposes
  `brick`, which is not a unit, and so resolves to nothing.

  """

  # Units whose plural is not formed by rule.
  @irregular %{
    "foot" => ["feet"],
    "radius" => ["radii", "radiuses"]
  }

  @singular_of_irregular for {singular, plurals} <- @irregular,
                             plural <- plurals,
                             into: %{},
                             do: {plural, singular}

  # Units with no distinct English plural. Either the plural is identical to
  # the singular (`hertz`, `siemens`), the name is a scale rather than a
  # countable unit (`celsius`), the name is a ratio (`percent`), or the name is
  # a modifier that never stands alone as a unit (`ofhg`, used to qualify a
  # pressure). Listing `celsiuses` or `ofhgs` as aliases would add noise to
  # `suggest/2` without ever matching anything a user would type.
  #
  # This governs `plural/1`, and so the derived alias table, only. A user who
  # does type `celsiuses` still resolves it, because `singularize/1` is applied
  # at resolution time and is deliberately lenient — it costs nothing to accept
  # a spelling nobody would suggest.
  @no_plural ~w(
    celsius fahrenheit
    hertz siemens lux beaufort
    percent permille permyriad
    ofglucose ofhg
    light-speed gasoline-energy-density
  )

  # Trailing segments of a hyphenated unit name that qualify a head noun rather
  # than being the head themselves. `fluid-ounce-imperial` pluralises to
  # `fluid-ounces-imperial`, not `fluid-ounce-imperials`.
  @qualifiers ~w(jp it us imperial metric person troy cloth length scandinavian)

  # British and other spellings that CLDR does not use. Applied as a substring
  # rewrite towards the CLDR spelling, so `millilitres` reaches `milliliters`
  # and picks up SI prefixes for free.
  @spellings %{"metre" => "meter", "litre" => "liter", "gramme" => "gram"}

  @vowels ~w(a e i o u)

  @doc """
  Returns the English plural forms of a CLDR unit name.

  ### Arguments

  * `name` - a CLDR unit name such as `"month"` or `"fluid-ounce-imperial"`.

  ### Returns

  * A list of plural spellings, which may be empty for a unit that has no
    distinct plural such as `"hertz"`.

  ### Examples

      iex> Unity.Aliases.Plural.plural("month")
      ["months"]

      iex> Unity.Aliases.Plural.plural("century")
      ["centuries"]

      iex> Unity.Aliases.Plural.plural("foot")
      ["feet"]

      iex> Unity.Aliases.Plural.plural("fluid-ounce-imperial")
      ["fluid-ounces-imperial"]

      iex> Unity.Aliases.Plural.plural("hertz")
      []

  """
  @spec plural(String.t()) :: [String.t()]
  def plural(name) when is_binary(name) do
    if name in @no_plural do
      []
    else
      name
      |> map_head_segment(&pluralize_word/1)
      |> Enum.reject(&(&1 == name))
    end
  end

  @doc """
  Returns alternative spellings of a unit name to try when it does not resolve
  as written.

  Combines singularisation with the spelling rewrites, so a British plural of
  an SI-prefixed unit such as `"millilitres"` reaches `"milliliter"`.

  ### Arguments

  * `name` - the unit name that failed to resolve.

  ### Returns

  * A list of candidate spellings, most likely first, excluding `name` itself.
    Each candidate must still be confirmed as a real unit by the caller.

  ### Examples

      iex> Unity.Aliases.Plural.candidates("milliseconds")
      ["millisecond"]

      iex> Unity.Aliases.Plural.candidates("metre")
      ["meter"]

      iex> "millilitres" |> Unity.Aliases.Plural.candidates() |> Enum.member?("milliliter")
      true

      iex> Unity.Aliases.Plural.candidates("bricks")
      ["brick"]

  """
  @spec candidates(String.t()) :: [String.t()]
  def candidates(name) when is_binary(name) do
    for spelling <- [name | respell(name)],
        candidate <- [spelling | singularize(spelling)],
        candidate != name,
        uniq: true,
        do: candidate
  end

  @doc """
  Returns the singular forms to try for a name that looks like a plural.

  ### Arguments

  * `name` - a possibly plural unit name.

  ### Returns

  * A list of candidate singular spellings, which is empty when `name` does not
    look like a plural.

  ### Examples

      iex> Unity.Aliases.Plural.singularize("months")
      ["month"]

      iex> Unity.Aliases.Plural.singularize("centuries")
      ["century"]

      iex> Unity.Aliases.Plural.singularize("feet")
      ["foot"]

      iex> Unity.Aliases.Plural.singularize("month")
      []

  """
  @spec singularize(String.t()) :: [String.t()]
  def singularize(name) when is_binary(name) do
    name
    |> map_head_segment(&singularize_word/1)
    |> Enum.reject(&(&1 == name))
  end

  # Applies `fun` to the head noun of a hyphenated name, leaving any trailing
  # qualifier segments in place, and rejoins. `fun` returns a list of
  # spellings, so the result is a list of names.
  defp map_head_segment(name, fun) do
    segments = String.split(name, "-")
    {leading, qualifiers} = Enum.split_while(segments, &(&1 not in @qualifiers))

    case Enum.split(leading, max(length(leading) - 1, 0)) do
      {_init, []} ->
        []

      {init, [head]} ->
        for spelling <- fun.(head), do: Enum.join(init ++ [spelling] ++ qualifiers, "-")
    end
  end

  defp pluralize_word(word) do
    cond do
      plurals = Map.get(@irregular, word) ->
        plurals

      String.ends_with?(word, "y") and not vowel_stem?(word) ->
        [String.slice(word, 0..-2//1) <> "ies"]

      String.ends_with?(word, ~w(s x z ch sh)) ->
        [word <> "es"]

      true ->
        [word <> "s"]
    end
  end

  defp singularize_word(word) do
    cond do
      singular = Map.get(@singular_of_irregular, word) ->
        [singular]

      String.ends_with?(word, "ies") and byte_size(word) > 4 ->
        [String.slice(word, 0..-4//1) <> "y"]

      String.ends_with?(word, "es") and ends_with_sibilant?(String.slice(word, 0..-3//1)) ->
        [String.slice(word, 0..-3//1), String.slice(word, 0..-2//1)]

      String.ends_with?(word, "s") and not String.ends_with?(word, "ss") ->
        [String.slice(word, 0..-2//1)]

      true ->
        []
    end
  end

  defp respell(name) do
    Enum.reduce(@spellings, [], fn {from, to}, acc ->
      if String.contains?(name, from), do: [String.replace(name, from, to) | acc], else: acc
    end)
  end

  defp ends_with_sibilant?(stem), do: String.ends_with?(stem, ~w(s x z ch sh))

  defp vowel_stem?(word) do
    case String.slice(word, -2..-2//1) do
      "" -> true
      character -> character in @vowels
    end
  end
end
