defmodule ABX.Decoder do
  require Logger

  def decode_data(data, types) do
    types
    |> Enum.with_index()
    |> Enum.map(fn {type, i} ->
      data
      |> binary_part(32 * i, 32)
      |> decode_type(type, data)
    end)
    |> Enum.reduce_while([], fn
      {:ok, value}, values -> {:cont, [value | values]}
      :error, _ -> {:halt, :error}
    end)
    |> case do
      :error -> :error
      values -> {:ok, Enum.reverse(values)}
    end
  end

  @spec decode_type(<<_::256>>, term(), binary()) :: {:ok, term()} | :error
  def decode_type(<<_padding::bytes-size(12), address::bytes-size(20)>>, :address, _data) do
    {:ok, address}
  end

  def decode_type(<<uint::256>>, {:uint, _size}, _data) do
    {:ok, uint}
  end

  for i <- 1..32 do
    def decode_type(<<bytes::bytes-size(unquote(i)), _padding::bytes-size(unquote(32 - i))>>, {:bytes, unquote(i)}, _data) do
      {:ok, bytes}
    end
  end

  def decode_type(<<offset::256>>, :bytes, data) do
    <<_skipped::bytes-size(offset), len::256, bytes::bytes-size(len), _::bytes()>> = data
    {:ok, bytes}
  end

  def decode_type(<<offset::256>>, :string, data) do
    <<_skipped::bytes-size(offset), len::256, string::bytes-size(len), _::bytes()>> = data
    {:ok, string}
  end

  def decode_type(_, type, _data) do
    throw({:unknow_type, type})
  end
end
