defmodule ABX.SimpleWeb3Adapter do
  @callback post(
              url :: String.t(),
              body :: map() | [map()],
              headers :: Keyword.t(),
              opts :: Keyword.t()
            ) :: {:ok, map()} | {:error, term()}

  @callback http_endpoint() :: String.t()
  @optional_callbacks http_endpoint: 0

  defmacro __using__(_opts) do
    quote do
      @behaviour ABX.Web3Adapter
      @behaviour ABX.SimpleWeb3Adapter

      require Logger

      def http_endpoint(), do: raise("callback http_endpoint not implemented")

      def json_rpc(web3_endpoint, payload, opts) do
        web3_endpoint = opts[:url] || web3_endpoint

        with {:ok, %{status_code: 200} = resp} <-
               post(
                 web3_endpoint,
                 payload,
                 [{"content-type", "application/json"}],
                 opts
               ),
             {:ok, %{result: result}} <- Jason.decode(resp.body, keys: :atoms) do
          {:ok, result}
        else
          {:ok, %{error: %{code: code, message: message}}} ->
            Logger.error(
              "JSONRPC code error #{web3_endpoint} #{inspect(payload)}: #{code} #{message}"
            )

            {:error, code, message}

          {:ok, decoded} when is_list(decoded) ->
            results =
              decoded
              |> Enum.map(fn
                %{result: result} ->
                  result

                reason ->
                  Logger.error("JSONRPC decoded error: #{reason |> inspect}")
                  nil
              end)

            {:ok, results}

          {:error, error} ->
            Logger.error(
              "JSONRPC request error #{web3_endpoint} #{inspect(payload)}: #{inspect(error)}"
            )

            {:error, error}

          error ->
            Logger.error(
              "JSONRPC unknown error #{web3_endpoint} #{inspect(payload)}: #{inspect(error)}"
            )

            {:error, :unknown_error}
        end
      end

      def batch_request(web3_endpoint, batch, opts \\ []) do
        {requests, return_types} = Enum.unzip(batch)

        # batched_request =
        #   for {method, params} <- requests do
        #     %{id: "1", jsonrpc: "2.0", method: method, params: params}
        #   end
        batched_request =
          requests
          |> Enum.with_index(fn {method, params}, idx ->
            %{id: idx + 1, jsonrpc: "2.0", method: method, params: params}
          end)

        with {:ok, return_values} <- json_rpc(web3_endpoint, batched_request, opts) do
          results =
            return_values
            |> List.wrap()
            |> Enum.zip(return_types)
            |> Enum.map(fn {return_value, return_type} ->
              case decode_value(return_value, return_type) do
                {:ok, result} ->
                  unwrap(result)

                reason ->
                  Logger.error("batch_request decode_value error: #{reason |> inspect}")
                  nil
              end
            end)

          {:ok, results}
        else
          reason ->
            Logger.error("batch_request JSONRPC error: #{reason |> inspect}")
            {:error, :request_failed}
        end
      end

      @impl true
      @doc ""
      def request(web3_endpoint, {{method, params}, return_type}, opts \\ []) do
        payload = %{id: "1", jsonrpc: "2.0", method: method, params: params}

        with {:ok, return_value} <- json_rpc(web3_endpoint, payload, opts),
             {:ok, result} <- decode_value(return_value, return_type) do
          {:ok, unwrap(result)}
        else
          {:error, _code, error} ->
            {:error, error}

          {:error, error} ->
            {:error, error}

          :error ->
            {:error, :decode_failed}
        end
      end

      def unwrap([]), do: nil
      def unwrap([value]), do: value
      def unwrap(values) when is_list(values), do: List.to_tuple(values)
      def unwrap(value), do: value

      def decode_value(nil, _return_types) do
        {:ok, nil}
      end

      def decode_value(return_value, :raw) do
        {:ok, return_value}
      end

      def decode_value("0x" <> return_value, :hex) do
        decoded_value =
          return_value
          |> String.to_integer(16)

        {:ok, decoded_value}
      end

      def decode_value(return_value, decoder) when is_function(decoder, 1) do
        {:ok, decoder.(return_value)}
      end

      def decode_value("0x" <> return_value, return_types) do
        {:ok, data} = Base.decode16(return_value, case: :mixed)
        ABX.Decoder.decode_data(data, return_types)
      end

      use ABX.Web3API
      defoverridable ABX.SimpleWeb3Adapter
    end
  end
end
