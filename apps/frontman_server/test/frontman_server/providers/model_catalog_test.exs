defmodule FrontmanServer.Providers.ModelCatalogTest do
  use FrontmanServer.DataCase, async: true

  import FrontmanServer.Test.Fixtures.Accounts

  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Providers
  alias FrontmanServer.Providers.ModelCatalog

  setup {Req.Test, :set_req_test_from_context}
  setup {Req.Test, :verify_on_exit!}

  setup do
    user = user_fixture()
    scope = Scope.for_user(user)
    expires_at = DateTime.add(DateTime.utc_now(), 3600, :second)

    {:ok, _token} =
      Providers.upsert_oauth_token(
        scope,
        "openai_codex",
        "openai-access-token",
        "openai-refresh-token",
        expires_at,
        %{"account_id" => "account-123"}
      )

    {:ok, scope: scope}
  end

  test "lists only visible API-supported OpenAI models at GPT 5.5 or newer", %{scope: scope} do
    Req.Test.expect(:openai_model_catalog, fn conn ->
      assert conn.request_path == "/backend-api/codex/models"
      assert conn.query_string == "client_version=0.0.0"
      assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer openai-access-token"]
      assert Plug.Conn.get_req_header(conn, "chatgpt-account-id") == ["account-123"]

      Req.Test.json(conn, %{
        "models" => [
          openai_model("gpt-5.6", "GPT-5.6", "high", ["medium", "high", "xhigh"], 1),
          openai_model("gpt-5.5", "GPT-5.5", "medium", ["low", "medium", "high"], 2),
          openai_model("gpt-5.4", "GPT-5.4", "medium", ["medium", "high"], 3),
          openai_model("gpt-latest", "GPT latest", "medium", ["medium", "high"], 4),
          openai_model("gpt-5.7-hidden", "GPT-5.7 Hidden", "high", ["high"], 5)
          |> Map.put("visibility", "hidden"),
          openai_model("gpt-5.8-internal", "GPT-5.8 Internal", "high", ["high"], 6)
          |> Map.put("supported_in_api", false)
        ]
      })
    end)

    assert {:ok, catalog} = ModelCatalog.list(scope, "openai_codex")

    assert Enum.map(catalog.models, & &1.value) == [
             "openai_codex:gpt-5.6",
             "openai_codex:gpt-5.5"
           ]

    assert Enum.at(catalog.models, 0) == %{
             provider: "openai_codex",
             id: "gpt-5.6",
             value: "openai_codex:gpt-5.6",
             name: "GPT-5.6",
             default_reasoning_effort: "high",
             reasoning_efforts: ["medium", "high", "xhigh"],
             provider_reasoning_efforts: ["medium", "high", "xhigh"]
           }

    assert is_integer(catalog.revision)
  end

  test "keeps OpenAI models when the provider advertises newer reasoning levels", %{scope: scope} do
    model =
      openai_model(
        "gpt-5.6-sol",
        "GPT-5.6-Sol",
        "medium",
        ["low", "medium", "high", "xhigh", "max", "ultra"],
        1
      )

    Req.Test.expect(:openai_model_catalog, fn conn ->
      Req.Test.json(conn, %{"models" => [model]})
    end)

    assert {:ok, catalog} = ModelCatalog.list(scope, "openai_codex")

    assert [%{value: "openai_codex:gpt-5.6-sol", reasoning_efforts: efforts}] = catalog.models
    assert efforts == ["low", "medium", "high", "xhigh"]
  end

  test "returns the last successful catalog when a refresh fails", %{scope: scope} do
    model = openai_model("gpt-5.5", "GPT-5.5", "medium", ["medium", "high"], 1)

    Req.Test.expect(:openai_model_catalog, fn conn ->
      Req.Test.json(conn, %{"models" => [model]})
    end)

    assert {:ok, first_catalog} = ModelCatalog.list(scope, "openai_codex")

    Req.Test.expect(:openai_model_catalog, fn conn ->
      Req.Test.transport_error(conn, :timeout)
    end)

    assert {:ok, stale_catalog} = ModelCatalog.list(scope, "openai_codex")
    assert stale_catalog.models == first_catalog.models
    assert stale_catalog.revision == first_catalog.revision
  end

  test "provider config uses the dynamic direct catalog and keeps static providers", %{
    scope: scope
  } do
    {:ok, _key} = Providers.upsert_api_key(scope, "openrouter", "openrouter-key")

    Req.Test.expect(:openai_model_catalog, fn conn ->
      Req.Test.json(conn, %{
        "models" => [
          openai_model("gpt-5.5", "GPT-5.5", "medium", ["low", "medium", "high"], 1)
        ]
      })
    end)

    config = Providers.model_config_data(scope)
    openai_group = Enum.find(config.groups, &(&1.id == "openai_codex"))
    openrouter_group = Enum.find(config.groups, &(&1.id == "openrouter"))

    assert openai_group.options == [
             %{
               name: "GPT-5.5",
               value: "openai_codex:gpt-5.5",
               default_reasoning_effort: "medium",
               reasoning_efforts: ["low", "medium", "high"]
             }
           ]

    assert openrouter_group.options != []
    assert is_integer(config.revision)
  end

  test "rejects unsupported model-effort pairs", %{scope: scope} do
    Req.Test.expect(:openai_model_catalog, fn conn ->
      Req.Test.json(conn, %{
        "models" => [openai_model("gpt-5.5", "GPT-5.5", "medium", ["medium", "high"], 1)]
      })
    end)

    assert {:error, :unsupported_reasoning_effort} =
             Providers.validate_model_reasoning(scope, "openai_codex:gpt-5.5", "xhigh")
  end

  test "prepares dynamic direct models as inline ReqLLM specs", %{scope: scope} do
    assert {:ok, {model_spec, llm_opts}} =
             Providers.prepare_llm_args(
               scope,
               "openai_codex:gpt-5.9-codex",
               reasoning_effort: :xhigh
             )

    assert model_spec == %{provider: :openai_codex, id: "gpt-5.9-codex"}
    assert llm_opts[:reasoning_effort] == :xhigh
  end

  test "revalidates a stale OpenAI catalog with ETag", %{scope: scope} do
    model = openai_model("gpt-5.5", "GPT-5.5", "medium", ["medium", "high"], 1)

    Req.Test.expect(:openai_model_catalog, fn conn ->
      conn
      |> Plug.Conn.put_resp_header("etag", ~s("catalog-v1"))
      |> Req.Test.json(%{"models" => [model]})
    end)

    assert {:ok, first_catalog} = ModelCatalog.list(scope, "openai_codex")

    Req.Test.expect(:openai_model_catalog, fn conn ->
      assert Plug.Conn.get_req_header(conn, "if-none-match") == [~s("catalog-v1")]
      Plug.Conn.send_resp(conn, 304, "")
    end)

    assert {:ok, revalidated_catalog} = ModelCatalog.list(scope, "openai_codex")
    assert revalidated_catalog == first_catalog
  end

  test "lists paginated Anthropic models at Claude 4.6 or newer with normalized effort", %{
    scope: scope
  } do
    {:ok, _key} = Providers.upsert_api_key(scope, "anthropic", "anthropic-api-key")

    Req.Test.expect(:anthropic_model_catalog, 2, fn conn ->
      assert Plug.Conn.get_req_header(conn, "x-api-key") == ["anthropic-api-key"]
      assert Plug.Conn.get_req_header(conn, "anthropic-version") == ["2023-06-01"]

      case URI.decode_query(conn.query_string) do
        %{"after_id" => "claude-opus-4-6", "limit" => "100"} ->
          Req.Test.json(conn, %{
            "data" => [
              anthropic_model("claude-sonnet-4-7-20260701", "Claude Sonnet 4.7", [
                "medium",
                "high"
              ]),
              anthropic_model("claude-haiku-4-5-20251001", "Claude Haiku 4.5", ["low", "high"])
            ],
            "has_more" => false,
            "last_id" => "claude-haiku-4-5-20251001"
          })

        %{"limit" => "100"} ->
          Req.Test.json(conn, %{
            "data" => [
              anthropic_model("claude-opus-4-6", "Claude Opus 4.6", ["low", "high", "max"])
            ],
            "has_more" => true,
            "last_id" => "claude-opus-4-6"
          })
      end
    end)

    assert {:ok, catalog} = ModelCatalog.list(scope, "anthropic")

    assert Enum.map(catalog.models, & &1.value) == [
             "anthropic:claude-sonnet-4-7-20260701",
             "anthropic:claude-opus-4-6"
           ]

    assert Enum.find(catalog.models, &(&1.id == "claude-opus-4-6")) == %{
             provider: "anthropic",
             id: "claude-opus-4-6",
             value: "anthropic:claude-opus-4-6",
             name: "Claude Opus 4.6",
             default_reasoning_effort: "high",
             reasoning_efforts: ["low", "high", "xhigh"],
             provider_reasoning_efforts: ["low", "high", "max"]
           }
  end

  test "does not follow authenticated catalog redirects", %{scope: scope} do
    Req.Test.expect(:openai_model_catalog, fn conn ->
      conn
      |> Plug.Conn.put_resp_header("location", "https://attacker.example/models")
      |> Plug.Conn.send_resp(302, "")
    end)

    assert {:error, {:unexpected_status, 302}} = ModelCatalog.list(scope, "openai_codex")

    {:ok, _key} = Providers.upsert_api_key(scope, "anthropic", "anthropic-api-key")

    Req.Test.expect(:anthropic_model_catalog, fn conn ->
      conn
      |> Plug.Conn.put_resp_header("location", "https://attacker.example/models")
      |> Plug.Conn.send_resp(307, "")
    end)

    assert {:error, {:unexpected_status, 307}} = ModelCatalog.list(scope, "anthropic")
  end

  test "malformed refreshes preserve the last successful catalog", %{scope: scope} do
    model = openai_model("gpt-5.5", "GPT-5.5", "medium", ["medium", "high"], 1)

    Req.Test.expect(:openai_model_catalog, fn conn ->
      Req.Test.json(conn, %{"models" => [model]})
    end)

    assert {:ok, first_catalog} = ModelCatalog.list(scope, "openai_codex")

    Req.Test.expect(:openai_model_catalog, fn conn ->
      Req.Test.json(conn, %{
        "models" => [
          %{
            "slug" => "gpt-5.5",
            "visibility" => "list",
            "supported_in_api" => true
          }
        ]
      })
    end)

    assert {:ok, stale_catalog} = ModelCatalog.list(scope, "openai_codex")
    assert stale_catalog == first_catalog
  end

  test "malformed Anthropic capabilities preserve the last successful catalog", %{scope: scope} do
    {:ok, _key} = Providers.upsert_api_key(scope, "anthropic", "anthropic-api-key")
    valid_model = anthropic_model("claude-sonnet-4-7", "Claude Sonnet 4.7", ["high"])

    Req.Test.expect(:anthropic_model_catalog, fn conn ->
      Req.Test.json(conn, %{
        "data" => [valid_model],
        "has_more" => false,
        "last_id" => valid_model["id"]
      })
    end)

    assert {:ok, first_catalog} = ModelCatalog.list(scope, "anthropic")

    malformed_model = put_in(valid_model, ["capabilities", "effort", "high"], true)

    Req.Test.expect(:anthropic_model_catalog, fn conn ->
      Req.Test.json(conn, %{
        "data" => [malformed_model],
        "has_more" => false,
        "last_id" => malformed_model["id"]
      })
    end)

    assert {:ok, stale_catalog} = ModelCatalog.list(scope, "anthropic")
    assert stale_catalog == first_catalog
  end

  test "coalesces concurrent refreshes for the same user and provider", %{scope: scope} do
    first_model = openai_model("gpt-5.5", "GPT-5.5", "medium", ["medium"], 1)

    Req.Test.expect(:openai_model_catalog, fn conn ->
      Req.Test.json(conn, %{"models" => [first_model]})
    end)

    assert {:ok, _catalog} = ModelCatalog.list(scope, "openai_codex")

    parent = self()
    refreshed_model = openai_model("gpt-5.6", "GPT-5.6", "high", ["high"], 1)

    Req.Test.expect(:openai_model_catalog, fn conn ->
      send(parent, {:refresh_started, self()})

      receive do
        :finish_refresh -> Req.Test.json(conn, %{"models" => [refreshed_model]})
      end
    end)

    tasks =
      Enum.map(1..5, fn _index ->
        Task.async(fn -> ModelCatalog.list(scope, "openai_codex") end)
      end)

    assert_receive {:refresh_started, refresh_pid}, 1_000
    Process.sleep(100)
    send(refresh_pid, :finish_refresh)

    catalogs = Enum.map(tasks, &Task.await(&1, 2_000))

    assert Enum.all?(catalogs, fn
             {:ok, %{models: [%{value: "openai_codex:gpt-5.6"}]}} -> true
             _other -> false
           end)
  end

  defp anthropic_model(id, name, efforts) do
    effort_capabilities =
      efforts
      |> Map.new(&{&1, %{"supported" => true}})
      |> Map.put("supported", true)

    %{
      "id" => id,
      "display_name" => name,
      "created_at" => "2026-07-01T00:00:00Z",
      "type" => "model",
      "capabilities" => %{
        "thinking" => %{"supported" => true, "types" => ["adaptive"]},
        "effort" => effort_capabilities
      }
    }
  end

  defp openai_model(slug, name, default_effort, supported_efforts, priority) do
    %{
      "slug" => slug,
      "display_name" => name,
      "default_reasoning_level" => default_effort,
      "supported_reasoning_levels" =>
        Enum.map(supported_efforts, &%{"effort" => &1, "description" => String.upcase(&1)}),
      "visibility" => "list",
      "supported_in_api" => true,
      "priority" => priority
    }
  end
end
