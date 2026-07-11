# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Providers.ModelCatalog do
  @moduledoc "Discovers and normalizes direct-provider model catalogs."

  alias FrontmanServer.Accounts
  alias FrontmanServer.Providers
  alias FrontmanServer.Providers.ModelCatalog.{Anthropic, Cache, OpenAI}

  @fresh_ttl_ms :timer.minutes(5)

  @doc "Returns the normalized model catalog available to the scoped user."
  def list(scope, provider) when provider in ["openai_codex", "anthropic"] do
    with {:ok, {_model, llm_opts}} <-
           Providers.prepare_llm_args(scope, "#{provider}:catalog") do
      cache_key = {Accounts.scope_user_id(scope), provider}
      fingerprint = credential_fingerprint(llm_opts)
      fresh_ttl_ms = config() |> Keyword.get(:fresh_ttl_ms, @fresh_ttl_ms)

      adapter = adapter(provider)

      Cache.fetch(cache_key, fingerprint, fresh_ttl_ms, fn validator ->
        adapter.fetch(llm_opts, validator)
      end)
    end
  end

  @doc "Removes a scoped provider's cached catalog."
  def invalidate(scope, provider) when provider in ["openai_codex", "anthropic"] do
    Cache.delete({Accounts.scope_user_id(scope), provider})
  end

  def invalidate(_scope, _provider), do: :ok

  @doc "Finds normalized metadata for an available direct-provider model."
  def find(scope, model) when is_binary(model) do
    {provider, _model_id} = model_parts(model)

    with true <- provider in ["openai_codex", "anthropic"],
         {:ok, catalog} <- list(scope, provider),
         model_data when is_map(model_data) <- Enum.find(catalog.models, &(&1.value == model)) do
      {:ok, model_data}
    else
      false -> {:error, :not_direct_provider}
      nil -> {:error, :model_not_available}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc "Validates that a direct model and optional reasoning effort were advertised together."
  def validate_selection(scope, model, reasoning_effort) when is_binary(model) do
    {provider, _model_id} = model_parts(model)

    case provider in ["openai_codex", "anthropic"] do
      true -> validate_direct_selection(scope, provider, model, reasoning_effort)
      false when is_nil(reasoning_effort) -> {:ok, nil}
      false -> {:error, :reasoning_not_supported}
    end
  end

  defp validate_direct_selection(scope, provider, model, reasoning_effort) do
    with {:ok, catalog} <- list(scope, provider),
         model_data when is_map(model_data) <- Enum.find(catalog.models, &(&1.value == model)) do
      validate_reasoning_effort(model_data, reasoning_effort)
    else
      nil -> {:error, :model_not_available}
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_reasoning_effort(_model_data, nil), do: {:ok, nil}

  defp validate_reasoning_effort(model_data, effort) when is_binary(effort) do
    case Enum.member?(model_data.reasoning_efforts, effort) do
      true -> {:ok, effort}
      false -> {:error, :unsupported_reasoning_effort}
    end
  end

  defp validate_reasoning_effort(_model_data, _effort),
    do: {:error, :unsupported_reasoning_effort}

  defp model_parts(model) do
    case String.split(model, ":", parts: 2) do
      [provider, model_id] when provider != "" and model_id != "" -> {provider, model_id}
    end
  end

  defp adapter("openai_codex"), do: OpenAI
  defp adapter("anthropic"), do: Anthropic

  defp credential_fingerprint(llm_opts) do
    credential = {
      Keyword.get(llm_opts, :access_token),
      Keyword.get(llm_opts, :api_key),
      Keyword.get(llm_opts, :chatgpt_account_id)
    }

    :crypto.hash(:sha256, :erlang.term_to_binary(credential))
  end

  defp config, do: Application.get_env(:frontman_server, __MODULE__, [])
end
