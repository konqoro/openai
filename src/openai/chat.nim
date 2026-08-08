## Helpers for creating and reading OpenAI Chat Completions requests.

import relay
import jsonx
import ./[config, http]
import ./schema/chat_schema

export config
export chat_schema

const ChatCompletionsPath = "/chat/completions"

type
  ChatCreateParams* = OpenAIChatCompletionsIn
  ChatCreateResult* = OpenAIChatCompletionOut

proc chatPartText*(text: sink string): ChatCompletionContentPart =
  ## Creates a text content part.
  result = ChatCompletionContentPart(
    `type`: ChatCompletionContentPartType.text,
    text: text
  )

proc chatPartImageUrl*(url: sink string;
    detail = ChatImageDetail.auto): ChatCompletionContentPart =
  ## Creates an image content part backed by a URL or data URL.
  result = ChatCompletionContentPart(
    `type`: ChatCompletionContentPartType.image_url,
    image_url: ChatImageUrl(
      url: url,
      detail: detail
    )
  )

proc chatPartInputAudio*(data: sink string;
    format: ChatInputAudioFormat): ChatCompletionContentPart =
  ## Creates an encoded audio content part.
  result = ChatCompletionContentPart(
    `type`: ChatCompletionContentPartType.input_audio,
    input_audio: ChatInputAudio(
      data: data,
      format: format
    )
  )

proc chatContentText*(text: sink string): ChatCompletionMessageContent =
  ## Creates message content from text.
  result = ChatCompletionMessageContent(
    kind: ChatCompletionInputContentKind.text,
    text: text
  )

proc chatContentParts*(parts: sink seq[ChatCompletionContentPart]): ChatCompletionMessageContent =
  ## Creates message content from typed parts.
  result = ChatCompletionMessageContent(
    kind: ChatCompletionInputContentKind.parts,
    parts: parts
  )

proc chatSystemMessageText*(text: sink string; name: sink string = ""): ChatMessage =
  ## Creates a system message with text content.
  result = ChatMessage(
    role: ChatMessageRole.system,
    content: chatContentText(text),
    name: name
  )

proc chatDeveloperMessageText*(text: sink string; name: sink string = ""): ChatMessage =
  ## Creates a developer message with text content.
  result = ChatMessage(
    role: ChatMessageRole.developer,
    content: chatContentText(text),
    name: name
  )

proc chatUserMessageText*(text: sink string; name: sink string = ""): ChatMessage =
  ## Creates a user message with text content.
  result = ChatMessage(
    role: ChatMessageRole.user,
    content: chatContentText(text),
    name: name
  )

proc chatUserMessageParts*(parts: sink seq[ChatCompletionContentPart];
    name: sink string = ""): ChatMessage =
  ## Creates a user message with typed content parts.
  result = ChatMessage(
    role: ChatMessageRole.user,
    content: chatContentParts(parts),
    name: name
  )

proc chatAssistantMessageText*(text: sink string; name: sink string = ""): ChatMessage =
  ## Creates an assistant message with text content.
  result = ChatMessage(
    role: ChatMessageRole.assistant,
    content: chatContentText(text),
    name: name
  )

proc chatAssistantMessageToolCalls*(
    toolCalls: sink seq[ChatCompletionMessageToolCall]): ChatMessage =
  ## Creates an assistant message containing function calls.
  result = ChatMessage(
    role: ChatMessageRole.assistant,
    tool_calls: toolCalls
  )

proc chatToolMessageText*(text, toolCallId: sink string; name: sink string = ""): ChatMessage =
  ## Creates a function result message containing text.
  result = ChatMessage(
    role: ChatMessageRole.tool,
    content: chatContentText(text),
    name: name,
    tool_call_id: toolCallId
  )

proc chatToolMessageJson*[T](value: T; toolCallId: sink string;
    name: sink string = ""): ChatMessage =
  ## Creates a function result message containing JSON encoded as text.
  chatToolMessageText(toJson(value), toolCallId, name)

proc chatFunctionTool*(name: sink string; description: sink string = "";
    strict = true): ChatTool =
  ## Creates a function tool with an empty object parameter schema.
  result = ChatTool(
    `type`: ChatToolType.function,
    function: ChatFunctionDefinition(
      name: name,
      description: description,
      parameters: EmptyFunctionParametersSchema,
      strict: strict
    )
  )

proc chatFunctionTool*(name: sink string; description: sink string;
    parameters: sink RawJson; strict = true): ChatTool =
  ## Creates a function tool from a raw JSON parameter schema.
  result = ChatTool(
    `type`: ChatToolType.function,
    function: ChatFunctionDefinition(
      name: name,
      description: description,
      parameters: parameters,
      strict: strict
    )
  )

proc chatFunctionTool*[TSchema](name: sink string; description: sink string;
    parametersSchema: TSchema; strict = true): ChatTool =
  ## Creates a function tool from a serializable parameter schema.
  chatFunctionTool(name, description, RawJson(toJson(parametersSchema)), strict)

proc chatFunctionTool*[TSchema](name: sink string; parametersSchema: TSchema;
    strict = true): ChatTool =
  ## Creates a function tool without a description.
  chatFunctionTool(name, "", RawJson(toJson(parametersSchema)), strict)

type
  ChatNamedFunctionWire = object
    name: string

  ChatNamedToolChoiceWire = object
    `type`: string
    function: ChatNamedFunctionWire

proc chatToolChoiceFunction*(name: sink string): RawJson =
  ## Requires the model to call the named function tool.
  RawJson(toJson(ChatNamedToolChoiceWire(
    `type`: "function",
    function: ChatNamedFunctionWire(name: name)
  )))

let
  chatFormatText* = ChatResponseFormat(`type`: ChatResponseFormatType.text)
  chatFormatJsonObject* = ChatResponseFormat(`type`: ChatResponseFormatType.json_object)

proc chatFormatJsonSchema*(name: sink string; schema: sink RawJson;
    description: sink string = ""; strict = true): ChatResponseFormat =
  ## Creates a structured-output JSON Schema format.
  result = ChatResponseFormat(
    `type`: ChatResponseFormatType.json_schema,
    json_schema: ChatResponseFormatJsonSchema(
      name: name,
      description: description,
      schema: schema,
      strict: strict
    )
  )

proc chatFormatJsonSchema*[TSchema](name: sink string; schema: TSchema;
    description: sink string = ""; strict = true): ChatResponseFormat =
  ## Creates a structured-output format from a serializable schema.
  chatFormatJsonSchema(name, RawJson(toJson(schema)), description, strict)

proc chatCreate*(model: sink string; messages: sink seq[ChatMessage];
    stream = false; temperature = 1.0;
    maxCompletionTokens = 0;
    reasoningEffort = ChatReasoningEffort.unspecified;
    tools: sink seq[ChatTool] = @[];
    toolChoice = RawJson(""); responseFormat = chatFormatText;
    parallelToolCalls = true; metadata: sink RawJson = RawJson("");
    promptCacheKey: sink string = "";
    promptCacheOptions = ChatPromptCacheOptions();
    safetyIdentifier: sink string = ""; serviceTier: sink string = "";
    store = false): ChatCreateParams =
  ## Creates Chat Completions parameters without deprecated request fields.
  result = ChatCreateParams(
    model: model,
    messages: messages,
    stream: stream,
    temperature: temperature,
    max_completion_tokens: maxCompletionTokens,
    reasoning_effort: reasoningEffort,
    tools: tools,
    tool_choice: toolChoice,
    response_format: responseFormat,
    parallel_tool_calls: parallelToolCalls,
    metadata: metadata,
    prompt_cache_key: promptCacheKey,
    prompt_cache_options: promptCacheOptions,
    safety_identifier: safetyIdentifier,
    service_tier: serviceTier,
    store: store
  )

proc chatRequest*(cfg: OpenAIConfig; params: ChatCreateParams;
    requestId = 0'i64; timeoutMs = 0;
    headers: sink HttpHeaders = emptyHttpHeaders()): RequestSpec =
  ## Builds a Chat Completions HTTP request.
  request(cfg, hvPost, cfg.url & ChatCompletionsPath, params,
    requestId, timeoutMs, headers)

proc chatAdd*(batch: var RequestBatch; cfg: OpenAIConfig;
    params: ChatCreateParams; requestId = 0'i64; timeoutMs = 0;
    headers: sink HttpHeaders = emptyHttpHeaders()) =
  ## Adds a Chat Completions HTTP request to a Relay batch.
  requestAdd(batch, cfg, hvPost, cfg.url & ChatCompletionsPath, params,
    requestId, timeoutMs, headers)

proc chatParse*(body: string; dst: var ChatCreateResult): bool =
  ## Parses a non-streaming Chat Completions result.
  try:
    dst = fromJson(body, ChatCreateResult)
    result = true
  except CatchableError:
    result = false

proc raiseAccessorValueError(message: string) {.noinline, noreturn.} =
  raise newException(ValueError, message)

proc raiseInvalidChoiceIndex(i, choiceCount: int) {.inline, noreturn.} =
  raiseAccessorValueError("choice index " & $i &
    " out of range for " & $choiceCount & " choices")

proc raiseNoFunctionCallsAtChoice(i: int) {.inline, noreturn.} =
  raiseAccessorValueError("choice index " & $i & " has no function calls")

proc raiseNoTextPartsAtChoice(i: int) {.inline, noreturn.} =
  raiseAccessorValueError("choice index " & $i & " has no text parts")

proc ensureChoiceIndex(choiceCount, i: int) {.inline.} =
  if i < 0 or i >= choiceCount:
    raiseInvalidChoiceIndex(i, choiceCount)

proc firstNonEmptyTextPartIndex(content: ChatCompletionAssistantContent; i: int): int =
  if content.parts.len == 0:
    raiseNoTextPartsAtChoice(i)
  result = 0
  for partIdx in 0 ..< content.parts.len:
    if content.parts[partIdx].text.len > 0:
      result = partIdx
      return result

proc idOf*(x: ChatCreateResult): lent string {.inline.} =
  result = x.id

proc idOf*(x: var ChatCreateResult): var string {.inline.} =
  result = x.id

proc modelOf*(x: ChatCreateResult): lent string {.inline.} =
  result = x.model

proc modelOf*(x: var ChatCreateResult): var string {.inline.} =
  result = x.model

proc createdAt*(x: ChatCreateResult): int64 {.inline.} =
  result = x.created

proc inputTokens*(x: ChatCreateResult): int {.inline.} =
  result = x.usage.prompt_tokens

proc outputTokens*(x: ChatCreateResult): int {.inline.} =
  result = x.usage.completion_tokens

proc cachedInputTokens*(x: ChatCreateResult): int {.inline.} =
  result = x.usage.prompt_tokens_details.cached_tokens

proc reasoningTokens*(x: ChatCreateResult): int {.inline.} =
  result = x.usage.completion_tokens_details.reasoning_tokens

proc totalTokens*(x: ChatCreateResult): int {.inline.} =
  result = x.usage.total_tokens

proc choices*(x: ChatCreateResult): int {.inline.} =
  result = x.choices.len

proc finish*(x: ChatCreateResult; i = 0): ChatFinishReason {.inline.} =
  ensureChoiceIndex(x.choices.len, i)
  result = x.choices[i].finish_reason

proc firstText*(x: ChatCreateResult; i = 0): lent string =
  ensureChoiceIndex(x.choices.len, i)
  case x.choices[i].message.content.kind
  of ChatCompletionAssistantContentKind.none:
    raiseAccessorValueError("choice index " & $i & " has no content")
  of ChatCompletionAssistantContentKind.text:
    result = x.choices[i].message.content.text
  of ChatCompletionAssistantContentKind.parts:
    let partIdx = firstNonEmptyTextPartIndex(x.choices[i].message.content, i)
    result = x.choices[i].message.content.parts[partIdx].text

proc firstText*(x: var ChatCreateResult; i = 0): var string =
  ensureChoiceIndex(x.choices.len, i)
  case x.choices[i].message.content.kind
  of ChatCompletionAssistantContentKind.none:
    raiseAccessorValueError("choice index " & $i & " has no content")
  of ChatCompletionAssistantContentKind.text:
    result = x.choices[i].message.content.text
  of ChatCompletionAssistantContentKind.parts:
    let partIdx = firstNonEmptyTextPartIndex(x.choices[i].message.content, i)
    result = x.choices[i].message.content.parts[partIdx].text

proc parseFirstTextJson*[T](x: ChatCreateResult; dst: var T; i = 0): bool =
  try:
    dst = fromJson(x.firstText(i), T)
    result = true
  except CatchableError:
    result = false

proc allTextParts*(x: ChatCreateResult; i = 0): seq[string] =
  result = @[]
  ensureChoiceIndex(x.choices.len, i)
  if x.choices[i].message.content.kind == ChatCompletionAssistantContentKind.parts:
    for part in x.choices[i].message.content.parts:
      result.add(part.text)

proc functionCalls*(x: ChatCreateResult;
    i = 0): lent seq[ChatCompletionMessageToolCall] {.inline.} =
  ensureChoiceIndex(x.choices.len, i)
  result = x.choices[i].message.tool_calls

proc functionCalls*(x: var ChatCreateResult;
    i = 0): var seq[ChatCompletionMessageToolCall] {.inline.} =
  ensureChoiceIndex(x.choices.len, i)
  result = x.choices[i].message.tool_calls

proc hasFunctionCalls*(x: ChatCreateResult; i = 0): bool =
  ensureChoiceIndex(x.choices.len, i)
  result = x.choices[i].message.tool_calls.len > 0

proc firstCallId*(x: ChatCreateResult; i = 0): lent string {.inline.} =
  ensureChoiceIndex(x.choices.len, i)
  if x.choices[i].message.tool_calls.len == 0:
    raiseNoFunctionCallsAtChoice(i)
  result = x.choices[i].message.tool_calls[0].id

proc firstCallId*(x: var ChatCreateResult; i = 0): var string {.inline.} =
  ensureChoiceIndex(x.choices.len, i)
  if x.choices[i].message.tool_calls.len == 0:
    raiseNoFunctionCallsAtChoice(i)
  result = x.choices[i].message.tool_calls[0].id

proc firstCallName*(x: ChatCreateResult; i = 0): lent string {.inline.} =
  ensureChoiceIndex(x.choices.len, i)
  if x.choices[i].message.tool_calls.len == 0:
    raiseNoFunctionCallsAtChoice(i)
  result = x.choices[i].message.tool_calls[0].function.name

proc firstCallName*(x: var ChatCreateResult; i = 0): var string {.inline.} =
  ensureChoiceIndex(x.choices.len, i)
  if x.choices[i].message.tool_calls.len == 0:
    raiseNoFunctionCallsAtChoice(i)
  result = x.choices[i].message.tool_calls[0].function.name

proc firstCallArgs*(x: ChatCreateResult; i = 0): lent string {.inline.} =
  ensureChoiceIndex(x.choices.len, i)
  if x.choices[i].message.tool_calls.len == 0:
    raiseNoFunctionCallsAtChoice(i)
  result = x.choices[i].message.tool_calls[0].function.arguments

proc firstCallArgs*(x: var ChatCreateResult; i = 0): var string {.inline.} =
  ensureChoiceIndex(x.choices.len, i)
  if x.choices[i].message.tool_calls.len == 0:
    raiseNoFunctionCallsAtChoice(i)
  result = x.choices[i].message.tool_calls[0].function.arguments

proc parseFirstCallArgs*[T](x: ChatCreateResult; dst: var T; i = 0): bool =
  try:
    dst = fromJson(x.firstCallArgs(i), T)
    result = true
  except CatchableError:
    result = false
