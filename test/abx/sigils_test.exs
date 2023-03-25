defmodule ABX.SigilsTest do
  use ExUnit.Case

  import ABX.Sigils

  test "address sigil" do
    assert ~a/1/ == ABX.Types.Address.cast!(1)
  end

  test "gwei sigil" do
    assert ~g/1/ == 1_000_000_000
  end
end
