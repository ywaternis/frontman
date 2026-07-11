# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Providers.ModelCatalog.Anthropic do
  @moduledoc false

  @base_url "https://api.anthropic.com/v1"
  @subscription_betas "oauth-2025-04-20,interleaved-thinking-2025-05-14"
  @subscription_user_agent "claude-cli/2.1.112 (external, cli)"
  @canonical_efforts ["none", "minimal", "low", "medium", "high", "xhigh"]
  @max_pages 10

  def fetch(llm_opts, _validator) do
    case fetch_pages(llm_opts, nil, [], 0) do
      {:ok, models} ->
        case normalize_models(models) do
          {:ok, normalized_models} ->
            catalog = %{
              models: normalized_models,
              revision: System.system_time(:millisecond)
            }

            {:ok, catalog, nil}

          {:error, reason} ->
            {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp fetch_pages(_llm_opts, _after_id, _models, @max_pages),
    do: {:error, :pagination_limit_exceeded}

  defp fetch_pages(llm_opts, after_id, models, page_count) do
    params = [limit: 100] |> maybe_put_after_id(after_id) |> maybe_put_beta(llm_opts)

    case Req.get(
           base_url() <> "/models",
           Keyword.merge(req_options(),
             headers: headers(llm_opts),
             params: params,
             receive_timeout: 5_000,
             redirect: false,
             retry: false
           )
         ) do
      {:ok, response} -> handle_page_response(response, llm_opts, models, page_count)
      {:error, reason} -> {:error, reason}
    end
  end

  defp handle_page_response(
         %{
           status: 200,
           body: %{"data" => page_models, "has_more" => has_more, "last_id" => last_id}
         },
         llm_opts,
         models,
         page_count
       )
       when is_list(page_models) and is_boolean(has_more) do
    all_models = models ++ page_models

    case has_more do
      true when is_binary(last_id) and last_id != "" ->
        fetch_pages(llm_opts, last_id, all_models, page_count + 1)

      true ->
        {:error, :invalid_anthropic_pagination}

      false ->
        {:ok, all_models}
    end
  end

  defp handle_page_response(%{status: 200}, _llm_opts, _models, _page_count),
    do: {:error, :invalid_anthropic_response}

  defp handle_page_response(%{status: status}, _llm_opts, _models, _page_count),
    do: {:error, {:unexpected_status, status}}

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
          |> Enum.sort_by(&{&1.created_at, &1.id}, :desc)
          |> Enum.map(&Map.delete(&1, :created_at))

        {:ok, models}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp normalize_entry(
         %{
           "id" => id,
           "display_name" => name,
           "created_at" => created_at,
           "type" => "model"
         } = model
       )
       when is_binary(id) and is_binary(name) and is_binary(created_at) do
    case version_at_least?(id, {4, 6}) do
      true -> normalize_eligible_model(model, id, name, created_at)
      false -> {:ok, :skip}
    end
  end

  defp normalize_entry(_model), do: {:error, :invalid_anthropic_model}

  defp normalize_eligible_model(model, id, name, created_at) do
    with {:ok, provider_efforts} <- provider_efforts(model) do
      reasoning_efforts = provider_efforts |> Enum.map(&normalize_effort/1) |> Enum.uniq()

      {:ok,
       %{
         provider: "anthropic",
         id: id,
         value: "anthropic:#{id}",
         name: name,
         default_reasoning_effort: default_effort(reasoning_efforts),
         reasoning_efforts: reasoning_efforts,
         provider_reasoning_efforts: provider_efforts,
         created_at: created_at
       }}
    end
  end

  defp provider_efforts(%{"capabilities" => %{"effort" => effort}}) when is_map(effort) do
    with {:ok, provider_efforts} <- normalize_provider_efforts(effort) do
      case {Map.get(effort, "supported"), provider_efforts} do
        {true, []} -> {:error, :invalid_anthropic_effort_capabilities}
        {_supported, efforts} -> {:ok, efforts}
      end
    end
  end

  defp provider_efforts(%{"capabilities" => %{"effort" => _invalid}}),
    do: {:error, :invalid_anthropic_effort_capabilities}

  defp provider_efforts(_model), do: {:ok, []}

  defp normalize_provider_efforts(effort) do
    @canonical_efforts
    |> Enum.map(fn
      "xhigh" -> "max"
      value -> value
    end)
    |> Enum.reduce_while({:ok, []}, fn value, {:ok, supported} ->
      case Map.get(effort, value) do
        nil -> {:cont, {:ok, supported}}
        %{"supported" => true} -> {:cont, {:ok, supported ++ [value]}}
        %{"supported" => false} -> {:cont, {:ok, supported}}
        _invalid -> {:halt, {:error, :invalid_anthropic_effort_capabilities}}
      end
    end)
  end

  defp normalize_effort("max"), do: "xhigh"
  defp normalize_effort(effort), do: effort

  defp default_effort(reasoning_efforts) do
    case "high" in reasoning_efforts do
      true -> "high"
      false -> List.first(reasoning_efforts)
    end
  end

  defp version_at_least?(id, minimum) do
    case Regex.run(
           ~r/^claude-(?:opus|sonnet|haiku)-(\d+)-(\d+)(?:$|-)/,
           id,
           capture: :all_but_first
         ) do
      [major, minor] -> {String.to_integer(major), String.to_integer(minor)} >= minimum
      nil -> false
    end
  end

  defp headers(llm_opts) do
    base = [{"anthropic-version", "2023-06-01"}]

    case {Keyword.get(llm_opts, :access_token), Keyword.get(llm_opts, :api_key)} do
      {access_token, _api_key} when is_binary(access_token) ->
        [
          {"authorization", "Bearer #{access_token}"},
          {"anthropic-beta", @subscription_betas},
          {"user-agent", @subscription_user_agent},
          {"x-app", "claude-code"}
          | base
        ]

      {nil, api_key} when is_binary(api_key) ->
        [{"x-api-key", api_key} | base]
    end
  end

  defp maybe_put_after_id(params, nil), do: params
  defp maybe_put_after_id(params, after_id), do: Keyword.put(params, :after_id, after_id)

  defp maybe_put_beta(params, llm_opts) do
    case Keyword.get(llm_opts, :access_token) do
      access_token when is_binary(access_token) -> Keyword.put(params, :beta, true)
      nil -> params
    end
  end

  defp base_url do
    config() |> Keyword.get(:base_url, @base_url)
  end

  defp req_options do
    config() |> Keyword.get(:req_options, [])
  end

  defp config, do: Application.get_env(:frontman_server, __MODULE__, [])
end
