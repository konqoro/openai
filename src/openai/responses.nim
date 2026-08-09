## Helpers for creating and reading OpenAI Responses API requests.

import relay
import jsonx
import ./[config, http]
import ./schema/responses_schema

export config
export responses_schema

const ResponsesPath = "/responses"

type
  ResponseCreateParams* = OpenAIResponseIn
  ResponseCreateResult* = OpenAIResponseOut

let responseFormatText* = ResponseTextFormat(`type`: ResponseTextFormatType.text)

proc responseInputText*(text: sink string): ResponseInput =
  ## Creates a plain-text Responses API input.
  ResponseInput(kind: ResponseInputKind.text, text: text)

proc responseInputItems*(items: sink seq[RawJson]): ResponseInput =
  ## Creates an input from message, function-result, or other API items.
  ResponseInput(kind: ResponseInputKind.items, items: items)

proc responsePartText*(text: sink string): ResponseInputContent =
  ## Creates an input text content part.
  ResponseInputContent(`type`: ResponseInputContentType.input_text, text: text)

proc responsePartImageUrl*(url: sink string; detail = "auto"): ResponseInputContent =
  ## Creates an image input content part backed by a URL or data URL.
  result = ResponseInputContent(
    `type`: ResponseInputContentType.input_image,
    image_url: url,
    detail: detail
  )

proc responsePartImageFile*(fileId: sink string; detail = "auto"): ResponseInputContent =
  ## Creates an image input content part backed by an uploaded file.
  result = ResponseInputContent(
    `type`: ResponseInputContentType.input_image,
    file_id: fileId,
    detail: detail
  )

proc responsePartFileUrl*(url: sink string): ResponseInputContent =
  ## Creates a file input content part backed by a URL.
  ResponseInputContent(`type`: ResponseInputContentType.input_file, file_url: url)

proc responsePartFileId*(fileId: sink string): ResponseInputContent =
  ## Creates a file input content part backed by an uploaded file.
  ResponseInputContent(`type`: ResponseInputContentType.input_file, file_id: fileId)

proc responsePartFileData*(data, filename: sink string): ResponseInputContent =
  ## Creates a file input content part from encoded file data.
  result = ResponseInputContent(
    `type`: ResponseInputContentType.input_file,
    file_data: data,
    filename: filename
  )

proc responseContentText*(text: sink string): ResponseContent =
  ## Creates message or function output content from text.
  result = ResponseContent(
    kind: ResponseContentKind.text,
    text: text
  )

proc responseContentParts*(
    parts: sink seq[ResponseInputContent]): ResponseContent =
  ## Creates message or function output content from typed parts.
  result = ResponseContent(
    kind: ResponseContentKind.parts,
    parts: parts
  )

proc responseMessageText*(role: ResponseInputRole;
    text: sink string): ResponseInputMessage =
  ## Creates a message input item with string content.
  result = ResponseInputMessage(
    role: role,
    content: responseContentText(text)
  )

proc responseMessageParts*(role: ResponseInputRole;
    parts: sink seq[ResponseInputContent]): ResponseInputMessage =
  ## Creates a message input item with typed content parts.
  result = ResponseInputMessage(
    role: role,
    content: responseContentParts(parts)
  )

proc responseFunctionOutput*(callId: sink string;
    output: sink string): ResponseFunctionOutput =
  ## Creates a function-call output item containing text.
  result = ResponseFunctionOutput(
    `type`: ResponseFunctionOutputType.function_call_output,
    call_id: callId,
    output: responseContentText(output)
  )

proc responseFunctionOutputParts*(callId: sink string;
    output: sink seq[ResponseInputContent]): ResponseFunctionOutput =
  ## Creates a function-call output item containing typed content parts.
  result = ResponseFunctionOutput(
    `type`: ResponseFunctionOutputType.function_call_output,
    call_id: callId,
    output: responseContentParts(output)
  )

proc responseFunctionOutputJson*[T](callId: sink string;
    output: T): ResponseFunctionOutput =
  ## Creates a function-call output item containing JSON encoded as text.
  result = ResponseFunctionOutput(
    `type`: ResponseFunctionOutputType.function_call_output,
    call_id: callId,
    output: responseContentText(toJson(output))
  )

proc responseFunctionTool*(name: sink string; description: sink string = "";
    parameters: sink RawJson = EmptyResponseObjectSchema;
    strict = true): ResponseFunctionTool =
  ## Creates a function tool definition.
  result = ResponseFunctionTool(
    `type`: ResponseToolType.function,
    name: name,
    description: description,
    parameters: parameters,
    strict: strict
  )

proc responseFunctionTool*[TSchema](name: sink string; description: sink string;
    parametersSchema: TSchema; strict = true): ResponseFunctionTool =
  ## Creates a function tool definition from a serializable schema value.
  responseFunctionTool(name, description, RawJson(toJson(parametersSchema)), strict)

proc responseToolChoiceFunction*(name: sink string): ResponseNamedToolChoice =
  ## Requires the model to call the named function tool.
  ResponseNamedToolChoice(`type`: ResponseToolType.function, name: name)

proc responseFormatJsonSchema*(name: sink string; schema: sink RawJson;
    description: sink string = ""; strict = true): ResponseTextFormat =
  ## Creates a structured-output JSON Schema format.
  result = ResponseTextFormat(
    `type`: ResponseTextFormatType.json_schema,
    name: name,
    description: description,
    schema: schema,
    strict: strict
  )

proc responseFormatJsonSchema*[TSchema](name: sink string; schema: TSchema;
    description: sink string = ""; strict = true): ResponseTextFormat =
  ## Creates a structured-output format from a serializable schema value.
  responseFormatJsonSchema(name, RawJson(toJson(schema)), description, strict)

proc responseCreate*(model: sink string; input: sink ResponseInput;
    instructions: sink string = ""; maxOutputTokens = 0;
    reasoning = ResponseReasoning(); text = ResponseTextConfig();
    tools: sink seq[RawJson] = @[]; toolChoice = RawJson("");
    previousResponseId: sink string = ""; background = false;
    parallelToolCalls = true; store = true; stream = false;
    promptCacheKey: sink string = "";
    promptCacheOptions = ResponsePromptCacheOptions();
    temperature = 1.0; topLogprobs = 0;
    topP = 1.0): ResponseCreateParams =
  ## Creates parameters for `POST /responses` without deprecated fields.
  result = ResponseCreateParams(
    model: model,
    input: input,
    instructions: instructions,
    max_output_tokens: maxOutputTokens,
    reasoning: reasoning,
    text: text,
    tools: tools,
    tool_choice: toolChoice,
    previous_response_id: previousResponseId,
    background: background,
    parallel_tool_calls: parallelToolCalls,
    store: store,
    stream: stream,
    prompt_cache_key: promptCacheKey,
    prompt_cache_options: promptCacheOptions,
    temperature: temperature,
    top_logprobs: topLogprobs,
    top_p: topP
  )

proc responseRequest*(cfg: OpenAIConfig; params: ResponseCreateParams;
    requestId = 0'i64; timeoutMs = 0;
    headers: sink HttpHeaders = emptyHttpHeaders()): RequestSpec =
  ## Builds a Responses API HTTP request.
  request(cfg, hvPost, cfg.url & ResponsesPath, params,
    requestId, timeoutMs, headers)

proc responseAdd*(batch: var RequestBatch; cfg: OpenAIConfig;
    params: ResponseCreateParams; requestId = 0'i64; timeoutMs = 0;
    headers: sink HttpHeaders = emptyHttpHeaders()) =
  ## Adds a Responses API HTTP request to a Relay batch.
  requestAdd(batch, cfg, hvPost, cfg.url & ResponsesPath, params,
    requestId, timeoutMs, headers)

proc responseParse*(body: string; dst: var ResponseCreateResult;
    unknownFields: UnknownFieldPolicy = ufSkip): bool =
  ## Parses a non-streaming Responses API result.
  try:
    dst = fromJson(body, ResponseCreateResult,
      unknownFields = unknownFields)
    result = true
  except CatchableError:
    result = false

proc raiseResponseAccessorError(message: string) {.noinline, noreturn.} =
  raise newException(ValueError, message)

proc raiseInvalidOutputIndex(i, outputCount: int) {.inline, noreturn.} =
  raiseResponseAccessorError("output item index " & $i &
    " out of range for " & $outputCount & " output items")

proc raiseNoOutputText() {.inline, noreturn.} =
  raiseResponseAccessorError("response has no output text")

proc ensureOutputIndex(outputCount, i: int) {.inline.} =
  if i < 0 or i >= outputCount:
    raiseInvalidOutputIndex(i, outputCount)

proc firstNonEmptyTextPartLocation(
    x: ResponseCreateResult): tuple[outputIndex, partIndex: int] =
  for outputIndex in 0..<x.output.len:
    for partIndex in 0..<x.output[outputIndex].content.len:
      let part = x.output[outputIndex].content[partIndex]
      if part.`type` == ResponseOutputContentType.output_text and part.text.len > 0:
        return (outputIndex, partIndex)
  raiseNoOutputText()

proc idOf*(x: ResponseCreateResult): lent string {.inline.} =
  result = x.id

proc idOf*(x: var ResponseCreateResult): var string {.inline.} =
  result = x.id

proc modelOf*(x: ResponseCreateResult): lent string {.inline.} =
  result = x.model

proc modelOf*(x: var ResponseCreateResult): var string {.inline.} =
  result = x.model

proc createdAt*(x: ResponseCreateResult): float {.inline.} =
  x.created_at

proc outputItems*(x: ResponseCreateResult): int {.inline.} =
  x.output.len

proc outputItem*(x: ResponseCreateResult;
    outputIndex: int): lent ResponseOutputItem {.inline.} =
  ## Returns output item `outputIndex` after validating the index.
  ensureOutputIndex(x.output.len, outputIndex)
  result = x.output[outputIndex]

proc outputItem*(x: var ResponseCreateResult;
    outputIndex: int): var ResponseOutputItem {.inline.} =
  ## Returns a mutable view of output item `outputIndex` after validating the index.
  ensureOutputIndex(x.output.len, outputIndex)
  result = x.output[outputIndex]

proc firstText*(x: ResponseCreateResult): lent string =
  ## Returns the first non-empty output-text part in response order.
  let location = firstNonEmptyTextPartLocation(x)
  result = x.output[location.outputIndex].content[location.partIndex].text

proc firstText*(x: var ResponseCreateResult): var string =
  ## Returns a mutable view of the first non-empty output-text part in response order.
  let location = firstNonEmptyTextPartLocation(x)
  result = x.output[location.outputIndex].content[location.partIndex].text

proc parseFirstTextJson*[T](x: ResponseCreateResult; dst: var T;
    unknownFields: UnknownFieldPolicy = ufSkip): bool =
  ## Parses the first non-empty output text in response order as `T`.
  try:
    dst = fromJson(x.firstText(), T, unknownFields = unknownFields)
    result = true
  except CatchableError:
    result = false

proc allTextParts*(x: ResponseCreateResult): seq[string] =
  ## Returns all output-text parts in response order.
  result = @[]
  for item in x.output:
    for part in item.content:
      if part.`type` == ResponseOutputContentType.output_text:
        result.add(part.text)

proc functionCalls*(x: ResponseCreateResult): seq[ResponseOutputItem] =
  ## Returns all function-call output items in response order.
  result = @[]
  for item in x.output:
    if item.`type` == ResponseOutputItemType.function_call:
      result.add(item)

proc hasFunctionCalls*(x: ResponseCreateResult): bool =
  ## Returns whether the response contains a function-call output item.
  result = false
  for item in x.output:
    if item.`type` == ResponseOutputItemType.function_call:
      return true

proc firstCallId*(x: ResponseCreateResult): lent string =
  for i in 0..<x.output.len:
    if x.output[i].`type` == ResponseOutputItemType.function_call:
      return x.output[i].call_id
  raiseResponseAccessorError("response has no function calls")

proc firstCallId*(x: var ResponseCreateResult): var string =
  for i in 0..<x.output.len:
    if x.output[i].`type` == ResponseOutputItemType.function_call:
      return x.output[i].call_id
  raiseResponseAccessorError("response has no function calls")

proc firstCallName*(x: ResponseCreateResult): lent string =
  for i in 0..<x.output.len:
    if x.output[i].`type` == ResponseOutputItemType.function_call:
      return x.output[i].name
  raiseResponseAccessorError("response has no function calls")

proc firstCallName*(x: var ResponseCreateResult): var string =
  for i in 0..<x.output.len:
    if x.output[i].`type` == ResponseOutputItemType.function_call:
      return x.output[i].name
  raiseResponseAccessorError("response has no function calls")

proc firstCallArgs*(x: ResponseCreateResult): lent string =
  for i in 0..<x.output.len:
    if x.output[i].`type` == ResponseOutputItemType.function_call:
      return x.output[i].arguments
  raiseResponseAccessorError("response has no function calls")

proc firstCallArgs*(x: var ResponseCreateResult): var string =
  for i in 0..<x.output.len:
    if x.output[i].`type` == ResponseOutputItemType.function_call:
      return x.output[i].arguments
  raiseResponseAccessorError("response has no function calls")

proc parseFirstCallArgs*[T](x: ResponseCreateResult; dst: var T;
    unknownFields: UnknownFieldPolicy = ufSkip): bool =
  ## Parses the first function call's JSON arguments as `T`.
  try:
    dst = fromJson(x.firstCallArgs(), T, unknownFields = unknownFields)
    result = true
  except CatchableError:
    result = false

proc hasUsage*(x: ResponseCreateResult): bool {.inline.} =
  x.usage.isSome

proc usageOf(x: ResponseCreateResult): lent ResponseUsage {.inline.} =
  if x.usage.isNone:
    raiseResponseAccessorError("response has no usage data")
  result = x.usage.get

proc inputTokens*(x: ResponseCreateResult): int {.inline.} =
  x.usageOf().input_tokens

proc cachedInputTokens*(x: ResponseCreateResult): int {.inline.} =
  x.usageOf().input_tokens_details.cached_tokens

proc outputTokens*(x: ResponseCreateResult): int {.inline.} =
  x.usageOf().output_tokens

proc reasoningTokens*(x: ResponseCreateResult): int {.inline.} =
  x.usageOf().output_tokens_details.reasoning_tokens

proc totalTokens*(x: ResponseCreateResult): int {.inline.} =
  x.usageOf().total_tokens
