defmodule Unity.CLITest do
  @moduledoc """
  Covers the command line's dispatch on the success paths; a failure halts
  the VM, which a test cannot survive.

  Expected values follow from the foot's definition, exactly 0.3048
  meters: 3 meters are 9.842519685… feet, printed to six fractional
  digits, and the reciprocal is 0.3048 / 3 = 0.1016. One foot is 0.3048
  meters, and its reciprocal 3.280839895… meters.

  """

  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  test "a conversion prints the result and its reciprocal" do
    assert capture_io(fn -> Unity.CLI.main(["3 meters to feet"]) end) ==
             "9.84252 feet\n\t/ 0.1016\n"
  end

  test "the source and target may be separate arguments" do
    assert capture_io(fn -> Unity.CLI.main(["3 meters", "feet"]) end) ==
             "9.84252 feet\n\t/ 0.1016\n"
  end

  test "--strict, --one-line and their short forms leave out the reciprocal" do
    for switch <- ["--strict", "-s", "--one-line", "-1"] do
      assert capture_io(fn -> Unity.CLI.main([switch, "3 meters", "feet"]) end) ==
               "9.84252 feet\n"
    end
  end

  test "--list without a category lists the categories" do
    categories = Localize.Unit.known_categories() |> Enum.sort() |> Enum.join(", ")

    assert capture_io(fn -> Unity.CLI.main(["--list"]) end) == categories <> "\n"
    assert capture_io(fn -> Unity.CLI.main(["--list", "--strict"]) end) == categories <> "\n"
  end

  test "--list with a category lists its units" do
    units = capture_io(fn -> Unity.CLI.main(["--list", "length"]) end)

    assert "foot" in String.split(String.trim(units), ", ")
    assert "meter" in String.split(String.trim(units), ", ")
  end

  test "with no expression and no terminal, each line of standard input is evaluated" do
    input = "3 meters to feet\n\n1 foot to meters\n"

    assert capture_io([input: input], fn -> Unity.CLI.main([]) end) ==
             "9.84252 feet\n\t/ 0.1016\n0.3048 meters\n\t/ 3.28084\n"
  end
end
