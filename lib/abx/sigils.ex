defmodule ABX.Sigils do
  @moduledoc """
  Support some common sigils like ~a
  https://elixir-lang.org/getting-started/sigils.html
  """

  alias ABX.Types.Address

  # def sigil_i(string, []), do: String.to_integer(string)
  # def sigil_i(string, [?n]), do: -String.to_integer(string)

  @doc """
  iex>  ~a/1/
  """
  def sigil_a("0x" <> <<_::binary-40>> = address_string, _) do
    address_string
    |> Address.cast!()
  end

  def sigil_a(address_string, []), do: sigil_a(address_string, [?i])

  def sigil_a(address_string, [?i]) do
    address_string
    |> String.to_integer()
    |> Address.cast!()
  end

  def sigil_a(address_string, [?h]) do
    address_string
    |> String.to_integer(16)
    |> Address.cast!()
  end

  def sigil_g(gwei_string, []) do
    gw = String.to_integer(gwei_string)

    (gw * :math.pow(10, 9))
    |> trunc()
  end

  def sigil_g(wei_string, [?r]) do
    w = String.to_integer(wei_string)

    (w * :math.pow(10, -9))
    |> trunc()
  end
end
