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

proc partText*(text: sink string): ChatCompletionContentPart =
  result = ChatCompletionContentPart(
    `type`: ChatCompletionContentPartType.text,
    text: text
  )

proc partImageUrl*(url: sink string;
    detail = ImageDetail.auto): ChatCompletionContentPart =
  result = ChatCompletionContentPart(
    `type`: ChatCompletionContentPartType.image_url,
    image_url: ImageUrl(
      url: url,
      detail: detail
    )
  )

proc partInputAudio*(data: sink string;
    format: InputAudioFormat): ChatCompletionContentPart =
  result = ChatCompletionContentPart(
    `type`: ChatCompletionContentPartType.input_audio,
    input_audio: InputAudio(
      data: data,
      format: format
    )
  )

proc contentText*(text: sink string): ChatCompletionMessageContent =
  result = ChatCompletionMessageContent(
    kind: ChatCompletionInputContentKind.text,
    text: text
  )

proc contentParts*(parts: sink seq[ChatCompletionContentPart]): ChatCompletionMessageContent =
  result = ChatCompletionMessageContent(
    kind: ChatCompletionInputContentKind.parts,
    parts: parts
  )

proc systemMessageText*(text: sink string; name: sink string = ""): ChatMessage =
  result = ChatMessage(
    role: ChatMessageRole.system,
    content: contentText(text),
    name: name
  )

proc userMessageText*(text: sink string; name: sink string = ""): ChatMessage =
  result = ChatMessage(
    role: ChatMessageRole.user,
    content: contentText(text),
    name: name
  )

proc userMessageParts*(parts: sink seq[ChatCompletionContentPart];
    name: sink string = ""): ChatMessage =
  result = ChatMessage(
    role: ChatMessageRole.user,
    content: contentParts(parts),
    name: name
  )

proc assistantMessageText*(text: sink string; name: sink string = ""): ChatMessage =
  result = ChatMessage(
    role: ChatMessageRole.assistant,
    content: contentText(text),
    name: name
  )

proc assistantMessageToolCalls*(toolCalls: sink seq[ChatCompletionMessageToolCall]): ChatMessage =
  result = ChatMessage(
    role: ChatMessageRole.assistant,
    tool_calls: toolCalls
  )

proc toolMessageText*(text, toolCallId: sink string; name: sink string = ""): ChatMessage =
  result = ChatMessage(
    role: ChatMessageRole.tool,
    content: contentText(text),
    name: name,
    tool_call_id: toolCallId
  )

proc toolMessageJson*[T](value: T; toolCallId: sink string;
    name: sink string = ""): ChatMessage =
  toolMessageText(toJson(value), toolCallId, name)

proc toolFunction*(name: sink string; description: sink string = ""): ChatTool =
  result = ChatTool(
    `type`: ChatToolType.function,
    function: FunctionDefinition(
      name: name,
      description: description,
      parameters: EmptyFunctionParametersSchema
    )
  )

proc toolFunction*(name: sink string; description: sink string;
    parameters: sink RawJson): ChatTool =
  result = ChatTool(
    `type`: ChatToolType.function,
    function: FunctionDefinition(
      name: name,
      description: description,
      parameters: parameters
    )
  )

proc toolFunction*[TSchema](name: sink string; description: sink string;
    parametersSchema: TSchema): ChatTool =
  toolFunction(name, description, RawJson(toJson(parametersSchema)))

proc toolFunction*[TSchema](name: sink string; parametersSchema: TSchema): ChatTool =
  toolFunction(name, "", RawJson(toJson(parametersSchema)))

let
  formatText* = ResponseFormat(`type`: ResponseFormatType.text)
  formatJsonObject* = ResponseFormat(`type`: ResponseFormatType.json_object)

proc formatJsonSchema*(name: sink string; schema: sink RawJson;
    strict = true): ResponseFormat =
  result = ResponseFormat(
    `type`: ResponseFormatType.json_schema,
    json_schema: ResponseFormatJsonSchema(
      name: name,
      schema: schema,
      strict: strict
    )
  )

proc formatJsonSchema*[TSchema](name: sink string; schema: TSchema;
    strict = true): ResponseFormat =
  formatJsonSchema(name, RawJson(toJson(schema)), strict)

proc chatCreate*(model: sink string; messages: sink seq[ChatMessage];
    stream = false; temperature = 1.0; maxTokens = 0;
    maxCompletionTokens = 0; reasoningEffort = none(ReasoningEffort);
    seed = none(int64); store = none(bool);
    tools: sink seq[ChatTool] = @[];
    toolChoice = ToolChoice.none;
    responseFormat = formatText): ChatCreateParams =
  result = ChatCreateParams(
    model: model,
    messages: messages,
    stream: stream,
    temperature: temperature,
    max_tokens: maxTokens,
    max_completion_tokens: maxCompletionTokens,
    reasoning_effort: reasoningEffort,
    tools: tools,
    tool_choice: toolChoice,
    response_format: responseFormat,
    seed: seed,
    store: store
  )

proc chatRequest*(cfg: OpenAIConfig; params: ChatCreateParams;
    requestId = 0'i64; timeoutMs = 0;
    headers: sink HttpHeaders = emptyHttpHeaders()): RequestSpec =
  request(cfg, hvPost, cfg.url & ChatCompletionsPath, params,
    requestId, timeoutMs, headers)

proc chatAdd*(batch: var RequestBatch; cfg: OpenAIConfig;
    params: ChatCreateParams; requestId = 0'i64; timeoutMs = 0;
    headers: sink HttpHeaders = emptyHttpHeaders()) =
  requestAdd(batch, cfg, hvPost, cfg.url & ChatCompletionsPath, params,
    requestId, timeoutMs, headers)

proc chatParse*(body: string; dst: var ChatCreateResult): bool =
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

proc raiseNoToolCallsAtChoice(i: int) {.inline, noreturn.} =
  raiseAccessorValueError("choice index " & $i & " has no tool calls")

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

proc promptTokens*(x: ChatCreateResult): int {.inline.} =
  result = x.usage.prompt_tokens

proc completionTokens*(x: ChatCreateResult): int {.inline.} =
  result = x.usage.completion_tokens

proc totalTokens*(x: ChatCreateResult): int {.inline.} =
  result = x.usage.total_tokens

proc choices*(x: ChatCreateResult): int {.inline.} =
  result = x.choices.len

proc finish*(x: ChatCreateResult; i = 0): FinishReason {.inline.} =
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

proc calls*(x: ChatCreateResult; i = 0): lent seq[ChatCompletionMessageToolCall] {.inline.} =
  ensureChoiceIndex(x.choices.len, i)
  result = x.choices[i].message.tool_calls

proc calls*(x: var ChatCreateResult; i = 0): var seq[ChatCompletionMessageToolCall] {.inline.} =
  ensureChoiceIndex(x.choices.len, i)
  result = x.choices[i].message.tool_calls

proc hasToolCalls*(x: ChatCreateResult; i = 0): bool =
  ensureChoiceIndex(x.choices.len, i)
  result = x.choices[i].message.tool_calls.len > 0

proc firstCallId*(x: ChatCreateResult; i = 0): lent string {.inline.} =
  ensureChoiceIndex(x.choices.len, i)
  if x.choices[i].message.tool_calls.len == 0:
    raiseNoToolCallsAtChoice(i)
  result = x.choices[i].message.tool_calls[0].id

proc firstCallId*(x: var ChatCreateResult; i = 0): var string {.inline.} =
  ensureChoiceIndex(x.choices.len, i)
  if x.choices[i].message.tool_calls.len == 0:
    raiseNoToolCallsAtChoice(i)
  result = x.choices[i].message.tool_calls[0].id

proc firstCallName*(x: ChatCreateResult; i = 0): lent string {.inline.} =
  ensureChoiceIndex(x.choices.len, i)
  if x.choices[i].message.tool_calls.len == 0:
    raiseNoToolCallsAtChoice(i)
  result = x.choices[i].message.tool_calls[0].function.name

proc firstCallName*(x: var ChatCreateResult; i = 0): var string {.inline.} =
  ensureChoiceIndex(x.choices.len, i)
  if x.choices[i].message.tool_calls.len == 0:
    raiseNoToolCallsAtChoice(i)
  result = x.choices[i].message.tool_calls[0].function.name

proc firstCallArgs*(x: ChatCreateResult; i = 0): lent string {.inline.} =
  ensureChoiceIndex(x.choices.len, i)
  if x.choices[i].message.tool_calls.len == 0:
    raiseNoToolCallsAtChoice(i)
  result = x.choices[i].message.tool_calls[0].function.arguments

proc firstCallArgs*(x: var ChatCreateResult; i = 0): var string {.inline.} =
  ensureChoiceIndex(x.choices.len, i)
  if x.choices[i].message.tool_calls.len == 0:
    raiseNoToolCallsAtChoice(i)
  result = x.choices[i].message.tool_calls[0].function.arguments

proc parseFirstCallArgs*[T](x: ChatCreateResult; dst: var T; i = 0): bool =
  try:
    dst = fromJson(x.firstCallArgs(i), T)
    result = true
  except CatchableError:
    result = false
