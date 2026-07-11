# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Providers.ModelCatalog.Cache do
  @moduledoc false

  use GenServer

  @table __MODULE__

  def start_link(_opts), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)

  def fetch(key, fingerprint, fresh_ttl_ms, refresh_fun) when is_function(refresh_fun, 1) do
    case GenServer.call(
           __MODULE__,
           {:begin_fetch, key, fingerprint, fresh_ttl_ms},
           :infinity
         ) do
      {:refresh, refresh_key, refresh_ref, validator} ->
        result = refresh_fun.(validator)

        GenServer.call(
          __MODULE__,
          {:complete_fetch, refresh_key, refresh_ref, result},
          :infinity
        )

      result ->
        result
    end
  end

  def delete(key), do: GenServer.call(__MODULE__, {:delete, key})

  @impl true
  def init(:ok) do
    table = :ets.new(@table, [:set, :private])
    {:ok, %{table: table, pending: %{}}}
  end

  @impl true
  def handle_call({:begin_fetch, key, fingerprint, fresh_ttl_ms}, from, state) do
    case lookup(state.table, key, fingerprint, fresh_ttl_ms) do
      {:fresh, catalog} ->
        {:reply, {:ok, catalog}, state}

      cache_state ->
        begin_refresh(key, fingerprint, cache_state, from, state)
    end
  end

  def handle_call({:complete_fetch, refresh_key, refresh_ref, result}, _from, state) do
    case Map.get(state.pending, refresh_key) do
      %{refresh_ref: ^refresh_ref} = pending ->
        Process.demonitor(pending.monitor_ref, [:flush])
        {reply, state} = refresh_result(result, pending, state)
        Enum.each(pending.waiters, &GenServer.reply(&1, reply))
        {:reply, reply, update_in(state.pending, &Map.delete(&1, refresh_key))}

      _missing_or_stale ->
        {:reply, {:error, :stale_catalog_refresh}, state}
    end
  end

  def handle_call({:delete, key}, _from, state) do
    true = :ets.delete(state.table, key)
    {:reply, :ok, state}
  end

  @impl true
  def handle_info({:DOWN, monitor_ref, :process, _pid, reason}, state) do
    case pending_by_monitor(state.pending, monitor_ref) do
      nil ->
        {:noreply, state}

      {refresh_key, pending} ->
        {reply, state} = refresh_result({:error, {:refresh_crashed, reason}}, pending, state)
        Enum.each(pending.waiters, &GenServer.reply(&1, reply))
        {:noreply, update_in(state.pending, &Map.delete(&1, refresh_key))}
    end
  end

  defp lookup(table, key, fingerprint, fresh_ttl_ms) do
    case :ets.lookup(table, key) do
      [{^key, ^fingerprint, stored_at, catalog, validator}] ->
        case System.monotonic_time(:millisecond) - stored_at <= fresh_ttl_ms do
          true -> {:fresh, catalog}
          false -> {:stale, catalog, validator}
        end

      [{^key, _other_fingerprint, _stored_at, _catalog, _validator}] ->
        true = :ets.delete(table, key)
        :miss

      [] ->
        :miss
    end
  end

  defp begin_refresh(key, fingerprint, cache_state, from, state) do
    refresh_key = {key, fingerprint}

    case Map.get(state.pending, refresh_key) do
      nil ->
        {owner_pid, _tag} = from
        monitor_ref = Process.monitor(owner_pid)
        refresh_ref = make_ref()

        pending = %{
          monitor_ref: monitor_ref,
          refresh_ref: refresh_ref,
          waiters: [],
          key: key,
          fingerprint: fingerprint,
          stale_catalog: stale_catalog(cache_state)
        }

        reply = {:refresh, refresh_key, refresh_ref, validator(cache_state)}
        {:reply, reply, put_in(state, [:pending, refresh_key], pending)}

      pending ->
        updated = %{pending | waiters: [from | pending.waiters]}
        {:noreply, put_in(state, [:pending, refresh_key], updated)}
    end
  end

  defp refresh_result({:ok, catalog, new_validator}, pending, state) do
    :ok = put(state.table, pending.key, pending.fingerprint, catalog, new_validator)
    {{:ok, catalog}, state}
  end

  defp refresh_result({:not_modified, new_validator}, %{stale_catalog: catalog} = pending, state)
       when is_map(catalog) do
    :ok = put(state.table, pending.key, pending.fingerprint, catalog, new_validator)
    {{:ok, catalog}, state}
  end

  defp refresh_result({:error, _reason}, %{stale_catalog: catalog}, state)
       when is_map(catalog),
       do: {{:ok, catalog}, state}

  defp refresh_result({:error, reason}, _pending, state), do: {{:error, reason}, state}

  defp refresh_result(other, pending, state),
    do: refresh_result({:error, {:invalid_refresh_result, other}}, pending, state)

  defp put(table, key, fingerprint, catalog, validator) do
    entry = {key, fingerprint, System.monotonic_time(:millisecond), catalog, validator}
    true = :ets.insert(table, entry)
    :ok
  end

  defp pending_by_monitor(pending, monitor_ref) do
    Enum.find(pending, fn {_key, entry} -> entry.monitor_ref == monitor_ref end)
  end

  defp validator({:stale, _catalog, validator}), do: validator
  defp validator(:miss), do: nil

  defp stale_catalog({:stale, catalog, _validator}), do: catalog
  defp stale_catalog(:miss), do: nil
end
