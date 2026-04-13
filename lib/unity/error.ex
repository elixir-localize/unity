defmodule Unity.Error do
  @moduledoc """
  User-friendly error formatting for parse errors, evaluation errors,
  and unknown unit suggestions.

  All errors are returned as plain strings suitable for terminal display.

  """

  @doc """
  Formats an error for display to the user.

  ### Arguments

  * `error` - an error tuple or string.

  ### Returns

  A formatted error string prefixed with `**`.

  ### Examples

      iex> Unity.Error.format({:error, "unknown unit: \\"frobnicator\\""})
      "** Unknown unit: \\"frobnicator\\""

  """
  @spec format({:error, String.t()} | String.t()) :: String.t()
  def format({:error, message}) when is_binary(message) do
    format(message)
  end

  def format(message) when is_binary(message) do
    cond do
      String.starts_with?(message, "parse error:") ->
        "** Parse error:" <> String.trim_leading(message, "parse error:")

      String.starts_with?(message, "unknown unit:") ->
        "** Unknown unit:" <> String.trim_leading(message, "unknown unit:")

      String.starts_with?(message, "cannot ") ->
        "** " <> capitalize_first(message)

      String.starts_with?(message, "undefined variable:") ->
        "** Undefined variable:" <> String.trim_leading(message, "undefined variable:")

      String.starts_with?(message, "conversion error:") ->
        "** Conversion error:" <> String.trim_leading(message, "conversion error:")

      true ->
        "** Error: " <> message
    end
  end

  defp capitalize_first(<<first::utf8, rest::binary>>) do
    String.upcase(<<first::utf8>>) <> rest
  end
end
