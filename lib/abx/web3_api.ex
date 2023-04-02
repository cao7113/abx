defmodule ABX.Web3API do
  defmacro __using__(_opts) do
    quote do
      import unquote(__MODULE__)

      def_web3(:eth_getTransactionByHash, [tx], fn txn ->
        txn
        |> Map.update!(:gas, &hex_number/1)
        |> Map.update!(:gasPrice, &hex_number/1)
        |> Map.update!(:nonce, &hex_number/1)
        |> Map.update!(:blockNumber, &hex_number/1)
        |> Map.update!(:transactionIndex, &hex_number/1)
      end)

      def_web3(:eth_getTransactionReceipt, [tx], fn txn ->
        txn
        |> Map.update!(:status, &hex_number/1)
      end)

      def_web3(:eth_getBlockByHash, [hash, full], fn block ->
        block
        |> Map.update!(:number, &hex_number/1)
        |> Map.update!(:timestamp, &hex_number/1)
      end)

      def_web3(:eth_getBlockByNumber, [block, full], fn block ->
        block
        |> Map.update!(:number, &hex_number/1)
        |> Map.update!(:timestamp, &hex_number/1)
      end)

      def_web3(:eth_blockNumber, [], :hex)

      def_web3(:eth_gasPrice, [], :hex)

      def_web3(:eth_estimateGas, [txn, block], :hex)

      def_web3(:eth_getTransactionCount, [address, block], :hex)

      def_web3(:eth_sendRawTransaction, [signed_txn], :raw)

      def_web3(:eth_getLogs, [filter_object], fn logs ->
        [logs]
      end)

      def_web3(:eth_getBalance, [address, block], :hex)

      def_web3(:eth_feeHistory, [block_count, newest_block, reward_percentile], fn result ->
        result
        |> Map.update!(:oldestBlock, &hex_number/1)
        |> Map.update!(:baseFeePerGas, fn list -> Enum.map(list, &hex_number/1) end)
        |> Map.update(:reward, [], fn list -> Enum.map(list, &hex_number/1) end)
      end)

      def_web3(:eth_chainId, [], :hex)

      def_web3(:eth_syncing, [], fn result ->
        result
      end)
    end
  end

  defmacro def_web3(method, params, return_type) do
    req_method_name =
      Macro.underscore(method |> to_string)
      |> String.replace_prefix("eth_", "req_")

    req_sname = req_method_name |> String.to_atom()
    req_sname_with_slash = (req_method_name <> "!") |> String.to_atom()

    quote do
      def unquote(method)(unquote_splicing(params)) do
        {{unquote(method), unquote(params)}, unquote(return_type)}
      end

      def unquote(method)(web3_endpoint, unquote_splicing(params)) do
        request(web3_endpoint, {{unquote(method), unquote(params)}, unquote(return_type)})
      end

      def unquote(req_sname)(unquote_splicing(params), opts \\ []) do
        ep = opts[:http_endpoint] || opts[:rpc_endpoint] || opts[:endpoint] || http_endpoint()
        request(ep, {{unquote(method), unquote(params)}, unquote(return_type)}, opts)
      end

      def unquote(req_sname_with_slash)(unquote_splicing(params), opts \\ []) do
        {:ok, resp} = unquote(req_sname)(unquote_splicing(params), opts)
        resp
      end
    end
  end

  def hex_number(nil) do
    nil
  end

  def hex_number("0x" <> hex_string) do
    String.to_integer(hex_string, 16)
  end
end
