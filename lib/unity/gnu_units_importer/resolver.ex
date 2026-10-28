defmodule Unity.GnuUnitsImporter.Resolver do
  @moduledoc """
  Pass 2: resolves parsed GNU unit expressions into numeric factors
  and dimension maps relative to SI primitives.

  Each resolved unit becomes `{factor, dimensions}` where `dimensions`
  is a map of GNU primitive name to integer power. For example:

  * `foot` → `{0.3048, %{"m" => 1}}`
  * `newton` → `{1.0, %{"kg" => 1, "m" => 1, "s" => -2}}`

  Resolution is recursive with memoization via the process dictionary
  to keep stack frames small during deep chains.

  """

  @type dimensions :: %{String.t() => integer()}
  @type resolved :: {float(), dimensions()}

  @max_depth 30

  @doc """
  Resolves all definitions in the parsed data to `{factor, dimensions}` pairs.

  """
  @spec resolve_all(Unity.GnuUnitsImporter.Parser.parsed()) :: {:ok, %{String.t() => resolved()}}
  def resolve_all(parsed) do
    env = %{
      primitives: parsed.primitives,
      prefixes: parsed.prefixes,
      definitions: parsed.definitions,
      aliases: parsed.aliases
    }

    Process.put(:gnu_env, env)
    Process.put(:gnu_cache, %{})

    # Build efficient prefix lookup data: sorted prefix list (longest first)
    # and a set of known base names for O(1) remainder validation.
    sorted_prefixes = env.prefixes |> Map.keys() |> Enum.sort_by(&(-byte_size(&1)))

    known_bases_set =
      MapSet.new(Map.keys(env.primitives) ++ Map.keys(env.definitions) ++ Map.keys(env.aliases))

    Process.put(:gnu_sorted_prefixes, sorted_prefixes)
    Process.put(:gnu_known_bases, known_bases_set)

    all_names = Map.keys(parsed.definitions) ++ Map.keys(parsed.aliases)

    resolved =
      Enum.reduce(all_names, %{}, fn name, acc ->
        try do
          case resolve(name, 0) do
            {:ok, value} -> Map.put(acc, name, value)
            :error -> acc
          end
        rescue
          _ -> acc
        end
      end)

    Process.delete(:gnu_env)
    Process.delete(:gnu_cache)
    Process.delete(:gnu_sorted_prefixes)
    Process.delete(:gnu_known_bases)

    {:ok, resolved}
  end

  # ── Resolution with memoization ──

  defp resolve(_name, depth) when depth > @max_depth, do: :error

  defp resolve(name, depth) do
    cache = Process.get(:gnu_cache)

    case Map.get(cache, name) do
      :resolving -> :error
      {:ok, _} = hit -> hit
      :error -> :error
      nil -> do_resolve_cached(name, depth)
    end
  end

  defp do_resolve_cached(name, depth) do
    Process.put(:gnu_cache, Map.put(Process.get(:gnu_cache), name, :resolving))
    env = Process.get(:gnu_env)

    result =
      cond do
        Map.has_key?(env.primitives, name) ->
          {:ok, {1.0, %{name => 1}}}

        target = Map.get(env.aliases, name) ->
          resolve(target, depth + 1)

        expr = Map.get(env.definitions, name) ->
          eval_expression(expr, depth + 1)

        expr = Map.get(env.prefixes, name) ->
          eval_expression(expr, depth + 1)

        true ->
          try_prefix_expansion(name, depth)
      end

    cache_val = if match?({:ok, _}, result), do: result, else: :error
    Process.put(:gnu_cache, Map.put(Process.get(:gnu_cache), name, cache_val))
    result
  end

  # ── Expression evaluation ──

  defp eval_expression(expr, depth) do
    eval_token_list(tokenize(expr), depth)
  end

  # A value is a sum of terms (`5 ft + 7 in`, `26 miles + 385 yards`), each
  # term a quotient of products. `+` and `-` bind loosest, so the tokens are
  # split at them outside parentheses first; the terms must share their
  # dimensions, or the definition is refused.
  defp eval_token_list(tokens, depth) do
    case split_on_sum(tokens) do
      [] -> eval_quotient([], depth)
      [{1, term}] -> eval_quotient(term, depth)
      terms -> eval_sum(terms, depth)
    end
  end

  defp eval_sum(terms, depth) do
    Enum.reduce_while(terms, {:ok, nil}, fn {sign, tokens}, {:ok, acc} ->
      case eval_quotient(tokens, depth) do
        {:ok, {factor, dims}} -> add_term(acc, sign * factor, dims)
        :error -> {:halt, :error}
      end
    end)
  end

  defp add_term(nil, factor, dims) do
    {:cont, {:ok, {factor, dims}}}
  end

  defp add_term({acc_factor, dims}, factor, dims) do
    {:cont, {:ok, {acc_factor + factor, dims}}}
  end

  defp add_term(_acc, _factor, _dims) do
    {:halt, :error}
  end

  defp eval_quotient(tokens, depth) do
    case split_on_slash(tokens) do
      {num_tokens, []} ->
        eval_product(num_tokens, depth)

      {num_tokens, den_tokens} ->
        with {:ok, {nf, nd}} <- eval_product(num_tokens, depth),
             {:ok, {df, dd}} <- eval_product(den_tokens, depth) do
          {:ok, {nf / max(df, 1.0e-300), merge_dims(nd, negate_dims(dd))}}
        end
    end
  end

  defp eval_product([], _depth), do: {:ok, {1.0, %{}}}

  defp eval_product(tokens, depth) do
    consume_product(tokens, 1.0, %{}, depth)
  end

  defp consume_product([], factor, dims, _depth), do: {:ok, {factor, dims}}

  defp consume_product([:star | rest], factor, dims, depth) do
    consume_product(rest, factor, dims, depth)
  end

  defp consume_product([:lparen | rest], factor, dims, depth) do
    {inner, remaining} = extract_parens(rest, [], 1)

    case eval_token_list(inner, depth) do
      {:ok, {f, d}} ->
        {f2, d2, remaining} = maybe_power(remaining, f, d)
        consume_product(remaining, factor * f2, merge_dims(dims, d2), depth)

      :error ->
        :error
    end
  end

  defp consume_product([{:number, n} | rest], factor, dims, depth) do
    {n2, d2, remaining} = maybe_power(rest, n, %{})
    consume_product(remaining, factor * n2, merge_dims(dims, d2), depth)
  end

  defp consume_product([{:identifier, name} | rest], factor, dims, depth) do
    case resolve(name, depth) do
      {:ok, {f, d}} ->
        {f2, d2, remaining} = maybe_power(rest, f, d)
        consume_product(remaining, factor * f2, merge_dims(dims, d2), depth)

      :error ->
        :error
    end
  end

  defp consume_product([_ | rest], factor, dims, depth) do
    consume_product(rest, factor, dims, depth)
  end

  # Handle ^N or ^-N after a term
  defp maybe_power([:caret, {:number, n} | rest], factor, dims) do
    exp = trunc(n)
    {pow(factor, exp), pow_dims(dims, exp), rest}
  end

  defp maybe_power([:caret, {:identifier, "-"}, {:number, n} | rest], factor, dims) do
    exp = -trunc(n)
    {pow(factor, exp), pow_dims(dims, exp), rest}
  end

  defp maybe_power(rest, factor, dims), do: {factor, dims, rest}

  defp pow(base, exp) when exp >= 0, do: :math.pow(base, exp)
  defp pow(base, exp), do: :math.pow(base, exp)

  defp pow_dims(dims, exp), do: Map.new(dims, fn {k, v} -> {k, v * exp} end)

  # ── Prefix expansion ──

  defp try_prefix_expansion(name, depth) do
    sorted_prefixes = Process.get(:gnu_sorted_prefixes)
    known_bases = Process.get(:gnu_known_bases)

    result = Enum.find_value(sorted_prefixes, &split_known_prefix(name, &1, known_bases))

    case result do
      {prefix, remainder} ->
        prefix_expr = Map.fetch!(Process.get(:gnu_env).prefixes, prefix)

        with {:ok, {pf, _pd}} <- eval_expression(prefix_expr, depth + 1),
             {:ok, {bf, bd}} <- resolve(remainder, depth + 1) do
          {:ok, {pf * bf, bd}}
        end

      nil ->
        :error
    end
  end

  # Returns `{prefix, remainder}` when `name` starts with `prefix` and the
  # remainder is a known base unit, otherwise `nil` so `find_value` continues.
  defp split_known_prefix(name, prefix, known_bases) do
    if String.starts_with?(name, prefix) and byte_size(name) > byte_size(prefix) do
      remainder = binary_part(name, byte_size(prefix), byte_size(name) - byte_size(prefix))
      if MapSet.member?(known_bases, remainder), do: {prefix, remainder}
    end
  end

  # ── Helpers ──

  # Splits at `+` and `-` outside parentheses into `{sign, term_tokens}`
  # pairs. A sign with no term before it is unary and signs the next term.
  defp split_on_sum(tokens) do
    do_split_sum(tokens, [], 1, [], 0)
  end

  defp do_split_sum([], [], _sign, terms, _depth) do
    Enum.reverse(terms)
  end

  defp do_split_sum([], acc, sign, terms, _depth) do
    Enum.reverse([{sign, Enum.reverse(acc)} | terms])
  end

  defp do_split_sum([:plus | rest], [], _sign, terms, 0) do
    do_split_sum(rest, [], 1, terms, 0)
  end

  defp do_split_sum([:minus | rest], [], _sign, terms, 0) do
    do_split_sum(rest, [], -1, terms, 0)
  end

  defp do_split_sum([:plus | rest], acc, sign, terms, 0) do
    do_split_sum(rest, [], 1, [{sign, Enum.reverse(acc)} | terms], 0)
  end

  defp do_split_sum([:minus | rest], acc, sign, terms, 0) do
    do_split_sum(rest, [], -1, [{sign, Enum.reverse(acc)} | terms], 0)
  end

  defp do_split_sum([:lparen | rest], acc, sign, terms, depth) do
    do_split_sum(rest, [:lparen | acc], sign, terms, depth + 1)
  end

  defp do_split_sum([:rparen | rest], acc, sign, terms, depth) do
    do_split_sum(rest, [:rparen | acc], sign, terms, depth - 1)
  end

  defp do_split_sum([token | rest], acc, sign, terms, depth) do
    do_split_sum(rest, [token | acc], sign, terms, depth)
  end

  defp split_on_slash(tokens), do: do_split_slash(tokens, [], 0)

  defp do_split_slash([], acc, _), do: {Enum.reverse(acc), []}
  defp do_split_slash([:lparen | r], acc, d), do: do_split_slash(r, [:lparen | acc], d + 1)
  defp do_split_slash([:rparen | r], acc, d), do: do_split_slash(r, [:rparen | acc], d - 1)
  defp do_split_slash([:slash | r], acc, 0), do: {Enum.reverse(acc), r}
  defp do_split_slash([t | r], acc, d), do: do_split_slash(r, [t | acc], d)

  defp extract_parens([], acc, _), do: {Enum.reverse(acc), []}
  defp extract_parens([:rparen | r], acc, 1), do: {Enum.reverse(acc), r}
  defp extract_parens([:rparen | r], acc, d), do: extract_parens(r, [:rparen | acc], d - 1)
  defp extract_parens([:lparen | r], acc, d), do: extract_parens(r, [:lparen | acc], d + 1)
  defp extract_parens([t | r], acc, d), do: extract_parens(r, [t | acc], d)

  defp merge_dims(a, b) do
    Map.merge(a, b, fn _k, v1, v2 -> v1 + v2 end)
    |> Enum.reject(fn {_k, v} -> v == 0 end)
    |> Map.new()
  end

  defp negate_dims(dims), do: Map.new(dims, fn {k, v} -> {k, -v} end)

  # ── Tokenizer ──

  defp tokenize(expr) do
    expr |> String.trim() |> do_tokenize([]) |> Enum.reverse()
  end

  defp do_tokenize("", acc), do: acc

  defp do_tokenize(<<c, r::binary>>, acc) when c in [?\s, ?\t],
    do: do_tokenize(String.trim_leading(r), acc)

  defp do_tokenize("(" <> r, acc), do: do_tokenize(r, [:lparen | acc])
  defp do_tokenize(")" <> r, acc), do: do_tokenize(r, [:rparen | acc])
  defp do_tokenize("/" <> r, acc), do: do_tokenize(r, [:slash | acc])
  defp do_tokenize("*" <> r, acc), do: do_tokenize(r, [:star | acc])
  defp do_tokenize("^" <> r, acc), do: do_tokenize(r, [:caret | acc])

  defp do_tokenize(<<c, _::binary>> = input, acc) when c in ?0..?9 or c == ?. do
    {number, rest} = consume_number(input)
    do_tokenize(rest, [{:number, number} | acc])
  end

  defp do_tokenize("+" <> rest, acc) do
    do_tokenize(rest, [:plus | acc])
  end

  # After `^` a `-` is the exponent's sign, as `maybe_power/3` reads it.
  defp do_tokenize("-" <> rest, [:caret | _] = acc) when rest != "" do
    <<c, _::binary>> = rest

    if c in ?0..?9 do
      {number, rest} = consume_number(rest)
      do_tokenize(rest, [{:number, -number} | acc])
    else
      do_tokenize(rest, [{:identifier, "-"} | acc])
    end
  end

  # After a value a `-` subtracts; elsewhere it signs the number that
  # follows it, or the next term when no number follows.
  defp do_tokenize("-" <> rest, acc) when rest != "" do
    <<c, _::binary>> = rest

    if c in ?0..?9 and not value_token?(acc) do
      {number, rest} = consume_number(rest)
      do_tokenize(rest, [{:number, -number} | acc])
    else
      do_tokenize(rest, [:minus | acc])
    end
  end

  defp do_tokenize(<<c, _::binary>> = input, acc) when c in ?a..?z or c in ?A..?Z or c == ?_ do
    {name, rest} = consume_identifier(input)
    do_tokenize(rest, [{:identifier, name} | acc])
  end

  defp do_tokenize("|" <> rest, [{:number, num} | acc]) do
    {den, rest} = consume_number(String.trim_leading(rest))
    value = if den != 0, do: num / den, else: 0.0
    do_tokenize(rest, [{:number, value} | acc])
  end

  defp do_tokenize("-", acc), do: [:minus | acc]
  defp do_tokenize(<<_, rest::binary>>, acc), do: do_tokenize(rest, acc)

  # A `-` after a number, a name or a closing parenthesis is a subtraction.
  defp value_token?([{:number, _} | _]) do
    true
  end

  defp value_token?([{:identifier, _} | _]) do
    true
  end

  defp value_token?([:rparen | _]) do
    true
  end

  defp value_token?(_acc) do
    false
  end

  defp consume_number(input) do
    case Regex.run(~r/^([0-9]*\.?[0-9]+(?:[eE][+-]?[0-9]+)?)/, input) do
      [match, _] -> {parse_num(match), String.replace_prefix(input, match, "")}
      nil -> {0.0, input}
    end
  end

  defp parse_num(s) do
    case Float.parse(s) do
      {f, ""} ->
        f

      _ ->
        case Integer.parse(s) do
          {i, ""} -> i / 1
          _ -> 0.0
        end
    end
  end

  defp consume_identifier(input) do
    case Regex.run(~r/^([a-zA-Z_][a-zA-Z0-9_]*)/, input) do
      [match, _] -> {match, String.replace_prefix(input, match, "")}
      nil -> {"", input}
    end
  end
end
