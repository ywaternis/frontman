# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Providers.ModelCatalog.OpenAI do
  @moduledoc false

  @base_url "https://chatgpt.com/backend-api/codex"
  @reasoning_efforts ["none", "minimal", "low", "medium", "high", "xhigh"]

  def fetch(llm_opts, etag) do
    config = Application.get_env(:frontman_server, __MODULE__, [])
    base_url = Keyword.get(config, :base_url, @base_url)
    req_options = Keyword.get(config, :req_options, [])

    headers =
      [
        {"authorization", "Bearer #{Keyword.fetch!(llm_opts, :access_token)}"},
        {"chatgpt-account-id", Keyword.fetch!(llm_opts, :chatgpt_account_id)}
      ]
      |> maybe_put_etag(etag)

    case Req.get(
           base_url <> "/models",
           Keyword.merge(req_options,
             headers: headers,
             params: [client_version: client_version()],
             receive_timeout: 5_000,
             redirect: false,
             retry: false
           )
         ) do
      {:ok, %{status: 200, body: %{"models" => models}} = response} when is_list(models) ->
        case normalize_models(models) do
          {:ok, normalized_models} ->
            catalog = %{
              models: normalized_models,
              revision: System.system_time(:millisecond)
            }

            {:ok, catalog, response_etag(response)}

          {:error, reason} ->
            {:error, reason}
        end

      {:ok, %{status: 304} = response} ->
        {:not_modified, response_etag(response) || etag}

      {:ok, %{status: status}} ->
        {:error, {:unexpected_status, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp maybe_put_etag(headers, nil), do: headers
  defp maybe_put_etag(headers, etag), do: [{"if-none-match", etag} | headers]

  defp response_etag(response) do
    response
    |> Req.Response.get_header("etag")
    |> List.first()
  end

  defp normalize_models(models) do
    models
    |> Enum.reduce_while({:ok, []}, fn model, {:ok, normalized} ->
      case normalize_entry(model) do
        {:ok, :skip} -> {:cont, {:ok, normalized}}
        {:ok, entry} -> {:cont, {:ok, [entry | normalized]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, entries} ->
        models =
          entries
          |> Enum.sort_by(& &1.priority)
          |> Enum.map(&Map.delete(&1, :priority))

        {:ok, models}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp normalize_entry(%{"visibility" => visibility}) when visibility != "list",
    do: {:ok, :skip}

  defp normalize_entry(%{"supported_in_api" => false}), do: {:ok, :skip}

  defp normalize_entry(%{
         "slug" => slug,
         "display_name" => name,
         "default_reasoning_level" => default_effort,
         "supported_reasoning_levels" => supported_efforts,
         "visibility" => "list",
         "supported_in_api" => true,
         "priority" => priority
       })
       when is_binary(slug) and is_binary(name) and is_list(supported_efforts) and
              is_integer(priority) do
    case version_at_least?(slug, {5, 5}) do
      true -> normalize_eligible_model(slug, name, default_effort, supported_efforts, priority)
      false -> {:ok, :skip}
    end
  end

  defp normalize_entry(_model), do: {:error, :invalid_openai_model}

  defp normalize_eligible_model(slug, name, default_effort, supported_efforts, priority) do
    with {:ok, reasoning_efforts} <- normalize_reasoning_efforts(supported_efforts),
         :ok <- validate_default_effort(default_effort, reasoning_efforts) do
      {:ok,
       %{
         provider: "openai_codex",
         id: slug,
         value: "openai_codex:#{slug}",
         name: name,
         default_reasoning_effort: default_effort,
         reasoning_efforts: reasoning_efforts,
         provider_reasoning_efforts: reasoning_efforts,
         priority: priority
       }}
    end
  end

  defp normalize_reasoning_efforts(efforts) do
    Enum.reduce_while(efforts, {:ok, []}, fn
      %{"effort" => effort}, {:ok, normalized} when effort in @reasoning_efforts ->
        {:cont, {:ok, normalized ++ [effort]}}

      _invalid, _acc ->
        {:halt, {:error, :invalid_openai_reasoning_effort}}
    end)
  end

  defp validate_default_effort(nil, _efforts), do: :ok

  defp validate_default_effort(default_effort, efforts) when is_binary(default_effort) do
    case default_effort in efforts do
      true -> :ok
      false -> {:error, :invalid_openai_default_reasoning_effort}
    end
  end

  defp validate_default_effort(_default_effort, _efforts),
    do: {:error, :invalid_openai_default_reasoning_effort}

  defp version_at_least?(slug, minimum) do
    case Regex.run(~r/^gpt-(\d+)\.(\d+)(?:$|-)/, slug, capture: :all_but_first) do
      [major, minor] -> {String.to_integer(major), String.to_integer(minor)} >= minimum
      nil -> false
    end
  end

  defp client_version do
    :frontman_server
    |> Application.spec(:vsn)
    |> to_string()
  end
end
