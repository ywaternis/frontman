module ACP = FrontmanAiFrontmanProtocol.FrontmanProtocol__ACP

@schema
type reasoning = {
  supportedValues: array<string>,
  defaultValue: string,
}

@schema
type frontman = {reasoning: reasoning}

@schema
type modelMeta = {frontman: frontman}

@schema
type catalogFrontman = {catalogRevision: float}

@schema
type catalogMeta = {frontman: catalogFrontman}

let catalogRevision = (configOptions: array<ACP.sessionConfigOption>): option<float> => {
  configOptions
  ->ACP.findConfigOptionByCategory(ACP.Model)
  ->Option.flatMap(configOption =>
    switch configOption {
    | ACP.SelectConfigOption({_meta}) =>
      _meta->Option.map(meta => S.parseOrThrow(meta, ~to=catalogMetaSchema).frontman.catalogRevision)
    }
  )
}

let findModelOption = (
  configOptions: array<ACP.sessionConfigOption>,
  modelValue: ACP.sessionConfigValueId,
): option<ACP.sessionConfigSelectOption> => {
  configOptions
  ->ACP.findConfigOptionByCategory(ACP.Model)
  ->Option.flatMap(configOption =>
    switch configOption {
    | ACP.SelectConfigOption({options: ACP.Grouped(groups)}) =>
      groups->Array.findMap(group => group.options->Array.find(option => option.value == modelValue))
    | ACP.SelectConfigOption({options: ACP.Ungrouped(_)}) =>
      failwith("Model config option must use grouped options")
    }
  )
}

let forModel = (
  configOptions: array<ACP.sessionConfigOption>,
  modelValue: ACP.sessionConfigValueId,
): option<reasoning> => {
  findModelOption(configOptions, modelValue)->Option.flatMap(option =>
    option._meta->Option.map(meta => {
      let parsed = S.parseOrThrow(meta, ~to=modelMetaSchema).frontman.reasoning

      switch parsed.supportedValues->Array.includes(parsed.defaultValue) {
      | true => parsed
      | false => failwith("Model reasoning default must be supported")
      }
    })
  )
}

let configOptionForModel = (
  configOptions: array<ACP.sessionConfigOption>,
  modelValue: ACP.sessionConfigValueId,
): option<ACP.sessionConfigOption> => {
  switch (
    forModel(configOptions, modelValue),
    configOptions->ACP.findConfigOptionByCategory(ACP.ThoughtLevel),
  ) {
  | (Some(reasoning), Some(ACP.SelectConfigOption(config))) =>
    switch config.options {
    | ACP.Ungrouped(options) =>
      let supportedOptions = options->Array.filter(option =>
        reasoning.supportedValues->Array.includes(option.value)
      )
      Some(ACP.SelectConfigOption({...config, options: ACP.Ungrouped(supportedOptions)}))
    | ACP.Grouped(_) => failwith("Thought-level config option must use ungrouped options")
    }
  | _ => None
  }
}

let reconcile = (
  ~configOptions: array<ACP.sessionConfigOption>,
  ~modelValue: ACP.sessionConfigValueId,
  ~currentValue: option<ACP.sessionConfigValueId>,
): option<ACP.sessionConfigValueId> => {
  switch forModel(configOptions, modelValue) {
  | Some(reasoning) =>
    switch currentValue {
    | Some(value) if reasoning.supportedValues->Array.includes(value) => Some(value)
    | _ => Some(reasoning.defaultValue)
    }
  | None => None
  }
}
