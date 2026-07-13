open Vitest

module Reducer = Client__State__StateReducer
module Types = Client__State__Types
module ACP = FrontmanAiFrontmanProtocol.FrontmanProtocol__ACP

// Dummy callbacks for AcpSessionActive (reducer only checks the variant, not the callbacks)
let _dummySendPrompt: Types.sendPromptFn = (
  _,
  ~additionalBlocks as _,
  ~onComplete as _,
  ~_meta as _,
) => ()
let _dummyCancelPrompt: Types.cancelPromptFn = () => ()
let _dummyRetryTurn: Types.retryTurnFn = _ => ()
let _dummyLoadTask: Types.loadTaskFn = (_, ~needsHistory as _, ~onComplete as _) => ()
let _dummyDeleteSession: Types.deleteSessionFn = (_, ~onComplete as _) => ()

let _apiBaseUrl = "http://localhost:4000"

type browserWindow

@val external _browserWindow: browserWindow = "window"
@set external _setRuntimeConfig: (browserWindow, JSON.t) => unit = "__frontmanRuntime"

// Helper: base state with an active ACP session (needed to emit effects)
let _makeState = (
  ~selectedModelValue=None,
  ~selectedReasoningValue=None,
  ~latestCatalogRevision=None,
  ~pendingProviderAutoSelect=None,
): Types.state => {
  {
    tasks: Dict.make(),
    currentTask: Types.Task.New(Types.Task.makeNew(~previewUrl="http://localhost:3000")),
    acpSession: AcpSessionActive({
      sendPrompt: _dummySendPrompt,
      cancelPrompt: _dummyCancelPrompt,
      retryTurn: _dummyRetryTurn,
      loadTask: _dummyLoadTask,
      deleteSession: _dummyDeleteSession,
      apiBaseUrl: _apiBaseUrl,
    }),
    sessionInitialized: true,
    userProfile: None,
    openrouterKeySettings: {Types.source: Types.None, saveStatus: Types.Idle},
    anthropicKeySettings: {
      source: Types.None,
      saveStatus: Types.Idle,
    },
    fireworksKeySettings: {Types.source: Types.None, saveStatus: Types.Idle},
    nvidiaKeySettings: {Types.source: Types.None, saveStatus: Types.Idle},
    anthropicOAuthStatus: Types.NotConnected,
    openaiOAuthStatus: Types.OpenAINotConnected,
    configOptions: None,
    selectedModelValue,
    selectedReasoningValue,
    latestCatalogRevision,
    pendingProviderAutoSelect,
    sessionsLoadState: Types.SessionsNotLoaded,
    updateInfo: None,
    updateCheckStatus: UpdateNotChecked,
    updateBannerDismissed: false,
  }
}

// ============================================================================
// Sample ACP SessionConfigOption data (replaces old providerConfig/modelsConfig)
// ============================================================================

module SampleConfig = {
  // Helper to build a grouped model config option
  let _makeModelConfigOption = (
    ~groups: array<ACP.sessionConfigSelectGroup>,
  ): ACP.sessionConfigOption => {
    ACP.SelectConfigOption({
      id: "model",
      name: "Model",
      description: None,
      category: Some(ACP.Model),
      options: ACP.Grouped(groups),
      _meta: None,
    })
  }

  let _anthropicGroup: ACP.sessionConfigSelectGroup = {
    group: "anthropic",
    name: "Anthropic (Claude Pro/Max)",
    options: [
      {
        value: "anthropic:claude-sonnet-4-5",
        name: "Claude Sonnet 4.5",
        description: None,
        _meta: None,
      },
      {value: "anthropic:claude-opus-4-5", name: "Claude Opus 4.5", description: None, _meta: None},
    ],
    _meta: None,
  }

  let _openaiGroup: ACP.sessionConfigSelectGroup = {
    group: "openai_codex",
    name: "OpenAI",
    options: [
      {
        value: "openai_codex:gpt-5.1-codex-max",
        name: "GPT-5.1 Codex Max",
        description: None,
        _meta: None,
      },
      {value: "openai_codex:gpt-5.2", name: "GPT-5.2", description: None, _meta: None},
    ],
    _meta: None,
  }

  let _openrouterGroup: ACP.sessionConfigSelectGroup = {
    group: "openrouter",
    name: "OpenRouter",
    options: [
      {
        value: "openrouter:google/gemini-3-flash-preview",
        name: "Gemini 3 Flash Preview",
        description: None,
        _meta: None,
      },
      {
        value: "openrouter:anthropic/claude-haiku-4.5",
        name: "Claude Haiku 4.5",
        description: None,
        _meta: None,
      },
    ],
    _meta: None,
  }

  let _fireworksGroup: ACP.sessionConfigSelectGroup = {
    group: "fireworks",
    name: "Fireworks AI",
    options: [
      {
        value: "fireworks:accounts/fireworks/routers/kimi-k2p5-turbo",
        name: "Kimi K2.5 Turbo",
        description: None,
        _meta: None,
      },
    ],
    _meta: None,
  }

  let configWithAnthropic = [_makeModelConfigOption(~groups=[_anthropicGroup, _openrouterGroup])]

  let configWithOpenAI = [
    _makeModelConfigOption(~groups=[_openaiGroup, _anthropicGroup, _openrouterGroup]),
  ]

  let configWithOpenRouterOnly = [_makeModelConfigOption(~groups=[_openrouterGroup])]

  let configWithFireworksOnly = [_makeModelConfigOption(~groups=[_fireworksGroup])]

  let configWithNoModels = [_makeModelConfigOption(~groups=[])]

  let reasoningConfig = [
    _makeModelConfigOption(~groups=[
      {
        group: "anthropic",
        name: "Anthropic",
        options: [
          {
            value: "anthropic:claude-opus-4-6",
            name: "Claude Opus 4.6",
            description: None,
            _meta: Some(
              JSON.parseOrThrow(
                `{"frontman":{"reasoning":{"supportedValues":["low","high"],"defaultValue":"high"}}}`,
              ),
            ),
          },
          {
            value: "anthropic:claude-sonnet-4-7",
            name: "Claude Sonnet 4.7",
            description: None,
            _meta: Some(
              JSON.parseOrThrow(
                `{"frontman":{"reasoning":{"supportedValues":["low","medium"],"defaultValue":"medium"}}}`,
              ),
            ),
          },
        ],
        _meta: None,
      },
    ]),
    ACP.SelectConfigOption({
      id: "thought_level",
      name: "Reasoning",
      description: None,
      category: Some(ACP.ThoughtLevel),
      options: ACP.Ungrouped([
        {value: "low", name: "Low", description: None, _meta: None},
        {value: "medium", name: "Medium", description: None, _meta: None},
        {value: "high", name: "High", description: None, _meta: None},
      ]),
      _meta: None,
    }),
  ]

  let withRevision = (configOptions, revision) =>
    configOptions->Array.mapWithIndex((option, index) =>
      switch (index, option) {
      | (0, ACP.SelectConfigOption(config)) =>
        ACP.SelectConfigOption({...config, _meta: Some(revision->JSON.parseOrThrow)})
      | _ => option
      }
    )
}

describe("Initiating actions set pendingProviderAutoSelect eagerly", () => {
  test("ExchangeAnthropicOAuthCode sets pendingProviderAutoSelect to anthropic", t => {
    let state = _makeState()

    let (nextState, _effects) = Reducer.next(
      state,
      ExchangeAnthropicOAuthCode({code: "test-code", verifier: "test-verifier"}),
    )

    t->expect(nextState.pendingProviderAutoSelect)->Expect.toEqual(Some("anthropic"))
  })

  test("InitiateOpenAIOAuth sets pendingProviderAutoSelect to openai_codex", t => {
    let state = _makeState()

    let (nextState, _effects) = Reducer.next(state, InitiateOpenAIOAuth)

    t->expect(nextState.pendingProviderAutoSelect)->Expect.toEqual(Some("openai_codex"))
  })

  test("SaveApiKey sets pendingProviderAutoSelect for each provider", t => {
    let providerCases: array<(Reducer.apiKeyProvider, string)> = [
      (OpenRouter, "openrouter"),
      (Anthropic, "anthropic"),
      (Fireworks, "fireworks"),
    ]

    providerCases->Array.forEach(
      ((provider, expectedProviderId)) => {
        let (nextState, _effects) = Reducer.next(
          _makeState(),
          SaveApiKey({provider, key: "test-key"}),
        )

        t->expect(nextState.pendingProviderAutoSelect)->Expect.toEqual(Some(expectedProviderId))
      },
    )
  })
})

describe("Reasoning selection", () => {
  test("prompt metadata snapshots the selected model and reasoning effort", t => {
    _setRuntimeConfig(_browserWindow, JSON.parseOrThrow(`{"framework":"nextjs"}`))
    let capturedMeta: ref<option<JSON.t>> = ref(None)
    let state = {
      ..._makeState(
        ~selectedModelValue=Some("anthropic:claude-opus-4-6"),
        ~selectedReasoningValue=Some("high"),
      ),
      acpSession: AcpSessionActive({
        sendPrompt: (_, ~additionalBlocks as _, ~onComplete as _, ~_meta) =>
          capturedMeta.contents = _meta,
        cancelPrompt: _dummyCancelPrompt,
        retryTurn: _dummyRetryTurn,
        loadTask: _dummyLoadTask,
        deleteSession: _dummyDeleteSession,
        apiBaseUrl: _apiBaseUrl,
      }),
    }

    Reducer.sendMessageToAPIImpl(
      state,
      _ => (),
      ~message="Hello",
      ~attachments=[],
      ~annotations=[],
      ~taskId="task-1",
    )

    let meta = capturedMeta.contents->Option.getOrThrow->JSON.Decode.object->Option.getOrThrow
    t->expect(meta->Dict.get("model"))->Expect.toEqual(Some(JSON.Encode.string("anthropic:claude-opus-4-6")))
    t->expect(meta->Dict.get("reasoning_effort"))->Expect.toEqual(Some(JSON.Encode.string("high")))
  })

  test("older catalog revisions cannot replace newer reasoning configuration", t => {
    let state = _makeState()
    let currentConfig = SampleConfig.withRevision(
      SampleConfig.reasoningConfig,
      `{"frontman":{"catalogRevision":42}}`,
    )
    let staleConfig = SampleConfig.withRevision(
      SampleConfig.configWithOpenRouterOnly,
      `{"frontman":{"catalogRevision":41}}`,
    )
    let (currentState, _) = Reducer.next(
      state,
      ConfigOptionsReceived({configOptions: currentConfig}),
    )
    let (nextState, _) = Reducer.next(
      currentState,
      ConfigOptionsReceived({configOptions: staleConfig}),
    )

    t->expect(nextState.latestCatalogRevision)->Expect.toEqual(Some(42.0))
    t
    ->expect(nextState.selectedModelValue)
    ->Expect.toEqual(Some("anthropic:claude-opus-4-6"))
  })

  test("derives only the selected model's advertised reasoning choices", t => {
    let configOption = Client__ReasoningConfig.configOptionForModel(
      SampleConfig.reasoningConfig,
      "anthropic:claude-opus-4-6",
    )->Option.getOrThrow

    switch configOption {
    | ACP.SelectConfigOption({category: Some(ACP.ThoughtLevel), options: ACP.Ungrouped(options)}) =>
      t->expect(options->Array.map(option => option.value))->Expect.toEqual(["low", "high"])
    | _ => failwith("Expected ungrouped thought-level config")
    }
  })

  test("model changes preserve the current effort when the new model supports it", t => {
    let state = _makeState(
      ~selectedModelValue=Some("anthropic:claude-sonnet-4-7"),
      ~selectedReasoningValue=Some("low"),
    )
    let (configuredState, _) = Reducer.next(
      state,
      ConfigOptionsReceived({configOptions: SampleConfig.reasoningConfig}),
    )

    let (nextState, _) = Reducer.next(
      configuredState,
      SetSelectedModelValue({value: "anthropic:claude-opus-4-6"}),
    )

    t->expect(nextState.selectedReasoningValue)->Expect.toEqual(Some("low"))
  })

  test("model changes use the new model default when the current effort is unsupported", t => {
    let state = _makeState(
      ~selectedModelValue=Some("anthropic:claude-opus-4-6"),
      ~selectedReasoningValue=Some("high"),
    )
    let (configuredState, _) = Reducer.next(
      state,
      ConfigOptionsReceived({configOptions: SampleConfig.reasoningConfig}),
    )

    let (nextState, _) = Reducer.next(
      configuredState,
      SetSelectedModelValue({value: "anthropic:claude-sonnet-4-7"}),
    )

    t->expect(nextState.selectedReasoningValue)->Expect.toEqual(Some("medium"))
  })

  test("rejects an effort unsupported by the selected model", t => {
    let state = _makeState(~selectedModelValue=Some("anthropic:claude-opus-4-6"))
    let (configuredState, _) = Reducer.next(
      state,
      ConfigOptionsReceived({configOptions: SampleConfig.reasoningConfig}),
    )

    Expect.toThrow(
      t->expect(() => Reducer.next(configuredState, SetSelectedReasoningValue({value: "medium"}))),
    )
  })

  test("non-direct models clear reasoning selection", t => {
    let state = _makeState(
      ~selectedModelValue=Some("anthropic:claude-opus-4-6"),
      ~selectedReasoningValue=Some("high"),
    )
    let (configuredState, _) = Reducer.next(
      state,
      ConfigOptionsReceived({configOptions: SampleConfig.reasoningConfig}),
    )
    let combinedConfig = switch (
      SampleConfig.reasoningConfig->Array.get(1),
      SampleConfig.configWithOpenRouterOnly->Array.get(0),
    ) {
    | (Some(thoughtOption), Some(openrouterOption)) => [openrouterOption, thoughtOption]
    | _ => failwith("Missing sample config options")
    }
    let (refreshedState, _) = Reducer.next(
      configuredState,
      ConfigOptionsReceived({configOptions: combinedConfig}),
    )
    let (nextState, _) = Reducer.next(
      refreshedState,
      SetSelectedModelValue({value: "openrouter:google/gemini-3-flash-preview"}),
    )

    t->expect(nextState.selectedReasoningValue)->Expect.toEqual(None)
  })
})

describe("ConfigOptionsReceived auto-selects model from newly connected provider", () => {
  test("auto-selects first Anthropic model when pendingProviderAutoSelect is anthropic", t => {
    let state = _makeState(
      ~pendingProviderAutoSelect=Some("anthropic"),
      ~selectedModelValue=Some("openrouter:google/gemini-3-flash-preview"),
    )

    let (nextState, _effects) = Reducer.next(
      state,
      ConfigOptionsReceived({configOptions: SampleConfig.configWithAnthropic}),
    )

    t
    ->expect(nextState.selectedModelValue)
    ->Expect.toEqual(Some("anthropic:claude-sonnet-4-5"))
    t->expect(nextState.pendingProviderAutoSelect)->Expect.toEqual(None)
  })

  test("auto-selects first OpenAI model when pendingProviderAutoSelect is openai_codex", t => {
    let state = _makeState(
      ~pendingProviderAutoSelect=Some("openai_codex"),
      ~selectedModelValue=Some("openrouter:google/gemini-3-flash-preview"),
    )

    let (nextState, _effects) = Reducer.next(
      state,
      ConfigOptionsReceived({configOptions: SampleConfig.configWithOpenAI}),
    )

    t
    ->expect(nextState.selectedModelValue)
    ->Expect.toEqual(Some("openai_codex:gpt-5.1-codex-max"))
    t->expect(nextState.pendingProviderAutoSelect)->Expect.toEqual(None)
  })

  test("auto-selects first OpenRouter model when pendingProviderAutoSelect is openrouter", t => {
    let state = _makeState(
      ~pendingProviderAutoSelect=Some("openrouter"),
      ~selectedModelValue=Some("openrouter:anthropic/claude-haiku-4.5"),
    )

    let (nextState, _effects) = Reducer.next(
      state,
      ConfigOptionsReceived({configOptions: SampleConfig.configWithOpenRouterOnly}),
    )

    t
    ->expect(nextState.selectedModelValue)
    ->Expect.toEqual(Some("openrouter:google/gemini-3-flash-preview"))
    t->expect(nextState.pendingProviderAutoSelect)->Expect.toEqual(None)
  })

  test("auto-selects Fireworks model when pendingProviderAutoSelect is fireworks", t => {
    let state = _makeState(
      ~pendingProviderAutoSelect=Some("fireworks"),
      ~selectedModelValue=Some("openrouter:anthropic/claude-haiku-4.5"),
    )

    let (nextState, _effects) = Reducer.next(
      state,
      ConfigOptionsReceived({configOptions: SampleConfig.configWithFireworksOnly}),
    )

    t
    ->expect(nextState.selectedModelValue)
    ->Expect.toEqual(Some("fireworks:accounts/fireworks/routers/kimi-k2p5-turbo"))
    t->expect(nextState.pendingProviderAutoSelect)->Expect.toEqual(None)
  })

  test("selects the first available model when refresh removes the current selection", t => {
    let state = _makeState(~selectedModelValue=Some("openai_codex:gpt-5.9-removed"))

    let (nextState, _effects) = Reducer.next(
      state,
      ConfigOptionsReceived({configOptions: SampleConfig.configWithAnthropic}),
    )

    t
    ->expect(nextState.selectedModelValue)
    ->Expect.toEqual(Some("anthropic:claude-sonnet-4-5"))
    t->expect(nextState.pendingProviderAutoSelect)->Expect.toEqual(None)
  })

  test("selects first model when no selection and no pending provider", t => {
    let state = _makeState()

    let (nextState, _effects) = Reducer.next(
      state,
      ConfigOptionsReceived({configOptions: SampleConfig.configWithAnthropic}),
    )

    t
    ->expect(nextState.selectedModelValue)
    ->Expect.toEqual(Some("anthropic:claude-sonnet-4-5"))
  })

  test("falls back when the pending provider and current model are missing", t => {
    let state = _makeState(
      ~pendingProviderAutoSelect=Some("openai_codex"),
      ~selectedModelValue=Some("openai_codex:gpt-5.1-codex-max"),
    )

    let (nextState, _effects) = Reducer.next(
      state,
      ConfigOptionsReceived({configOptions: SampleConfig.configWithOpenRouterOnly}),
    )

    t
    ->expect(nextState.selectedModelValue)
    ->Expect.toEqual(Some("openrouter:google/gemini-3-flash-preview"))
    t->expect(nextState.pendingProviderAutoSelect)->Expect.toEqual(None)
  })

  test("accepts empty model config when no providers are configured", t => {
    let state = _makeState()

    let (nextState, _effects) = Reducer.next(
      state,
      ConfigOptionsReceived({configOptions: SampleConfig.configWithNoModels}),
    )

    t->expect(nextState.selectedModelValue)->Expect.toEqual(None)
    t->expect(nextState.pendingProviderAutoSelect)->Expect.toEqual(None)
  })
})
