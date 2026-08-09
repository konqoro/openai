## JSON-mapped types for the OpenAI Responses API.
##
## Deprecated API fields are deliberately absent from this schema.

import std/options
export options
import jsonx
import jsonx/[parsejson, streams]

type
  ResponseInputKind* = enum
    text, items

  ResponseInput* = object
    case kind*: ResponseInputKind
    of text:
      text*: string
    of items:
      items*: seq[RawJson]

  ResponseInputRole* = enum
    system, developer, user, assistant

  ResponseInputContentType* = enum
    input_text, input_image, input_file

  ResponseInputContent* = object
    `type`*: ResponseInputContentType
    text*: string
    image_url*: string
    file_id*: string
    file_url*: string
    filename*: string
    file_data*: string
    detail*: string

  ResponseContentKind* = enum
    text, parts

  ResponseContent* = object
    case kind*: ResponseContentKind
    of text:
      text*: string
    of parts:
      parts*: seq[ResponseInputContent]

  ResponseFunctionOutputType* = enum
    function_call_output

  ResponseFunctionOutput* = object
    `type`*: ResponseFunctionOutputType
    call_id*: string
    output*: ResponseContent

  ResponseTextFormatType* = enum
    text, json_schema

  ResponseTextFormat* = object
    `type`*: ResponseTextFormatType
    name*: string
    description*: string
    schema*: RawJson
    strict*: bool

  ResponseTextConfig* = object
    format*: ResponseTextFormat
    verbosity*: string

  ResponseReasoningEffort* = enum
    unspecified = ""
    none
    low
    medium
    high
    xhigh
    max

  ResponseReasoning* = object
    effort*: ResponseReasoningEffort
    summary*: string
    mode*: string
    context*: string

  ResponsePromptCacheOptions* = object
    mode*: string
    ttl*: string

  OpenAIResponseIn* = object
    model*: string
    input*: ResponseInput
    background*: bool
    context_management*: seq[RawJson]
    conversation*: string
    `include`*: seq[string]
    instructions*: string
    max_output_tokens*: int
    max_tool_calls*: int
    metadata*: RawJson
    moderation*: RawJson
    parallel_tool_calls*: bool = true
    previous_response_id*: string
    prompt*: RawJson
    prompt_cache_key*: string
    prompt_cache_options*: ResponsePromptCacheOptions
    reasoning*: ResponseReasoning
    safety_identifier*: string
    service_tier*: string
    store*: bool = true
    stream*: bool
    stream_options*: RawJson
    temperature*: float = 1.0
    text*: ResponseTextConfig
    tool_choice*: RawJson
    tools*: seq[RawJson]
    top_logprobs*: int
    top_p*: float = 1.0

  ResponseError* = object
    code*: string
    message*: string

  ResponseIncompleteDetails* = object
    reason*: string

  ResponseInputTokensDetails* = object
    cached_tokens*: int
    cache_write_tokens*: int

  ResponseOutputTokensDetails* = object
    reasoning_tokens*: int

  ResponseUsage* = object
    input_tokens*: int
    input_tokens_details*: ResponseInputTokensDetails
    output_tokens*: int
    output_tokens_details*: ResponseOutputTokensDetails
    total_tokens*: int

  ResponseOutputContent* = object
    `type`*: string
    text*: string
    refusal*: string
    annotations*: seq[RawJson]
    logprobs*: seq[RawJson]

  ResponseOutputItem* = object
    id*: string
    `type`*: string
    status*: string
    role*: string
    content*: seq[ResponseOutputContent]
    call_id*: string
    name*: string
    arguments*: string

  OpenAIResponseOut* = object
    id*: string
    `object`*: string
    created_at*: float
    completed_at*: Option[int64]
    background*: bool
    status*: string
    error*: Option[ResponseError]
    incomplete_details*: Option[ResponseIncompleteDetails]
    model*: string
    output*: seq[ResponseOutputItem]
    previous_response_id*: string
    service_tier*: string
    usage*: Option[ResponseUsage]
    metadata*: RawJson
    reasoning*: RawJson

const
  EmptyResponseObjectSchema* = RawJson("""{"type":"object","properties":{}}""")
  ResponseToolChoiceAuto* = RawJson("\"auto\"")
  ResponseToolChoiceNone* = RawJson("\"none\"")
  ResponseToolChoiceRequired* = RawJson("\"required\"")

template writeJsonField(s: Stream; name: string; value: untyped) =
  if comma: streams.write(s, ",")
  else: comma = true
  escapeJson(s, name)
  streams.write(s, ":")
  writeJson(s, value)

proc writeJson*(s: Stream; x: ResponseInput) =
  case x.kind
  of ResponseInputKind.text:
    writeJson(s, x.text)
  of ResponseInputKind.items:
    writeJson(s, x.items)

proc readJson*(dst: var ResponseContent; p: var JsonParser;
    unknownFields: UnknownFieldPolicy) =
  if p.tok == tkString:
    dst = ResponseContent(kind: ResponseContentKind.text)
    readJson(dst.text, p, unknownFields)
  elif p.tok == tkBracketLe:
    dst = ResponseContent(kind: ResponseContentKind.parts)
    readJson(dst.parts, p, unknownFields)
  else:
    raiseParseErr(p, "string or array")

proc writeJson*(s: Stream; x: ResponseInputContent) =
  var comma = false
  streams.write(s, "{")
  writeJsonField(s, "type", x.`type`)
  case x.`type`
  of ResponseInputContentType.input_text:
    writeJsonField(s, "text", x.text)
  of ResponseInputContentType.input_image:
    if x.image_url.len > 0:
      writeJsonField(s, "image_url", x.image_url)
    else:
      writeJsonField(s, "file_id", x.file_id)
    if x.detail.len > 0:
      writeJsonField(s, "detail", x.detail)
  of ResponseInputContentType.input_file:
    if x.file_id.len > 0:
      writeJsonField(s, "file_id", x.file_id)
    elif x.file_url.len > 0:
      writeJsonField(s, "file_url", x.file_url)
    else:
      writeJsonField(s, "file_data", x.file_data)
      if x.filename.len > 0:
        writeJsonField(s, "filename", x.filename)
  streams.write(s, "}")

proc writeJson*(s: Stream; x: ResponseContent) =
  case x.kind
  of ResponseContentKind.text:
    writeJson(s, x.text)
  of ResponseContentKind.parts:
    writeJson(s, x.parts)

proc writeJson*(s: Stream; x: ResponseTextFormat) =
  var comma = false
  streams.write(s, "{")
  writeJsonField(s, "type", x.`type`)
  if x.`type` == ResponseTextFormatType.json_schema:
    writeJsonField(s, "name", x.name)
    if x.description.len > 0:
      writeJsonField(s, "description", x.description)
    if string(x.schema).len > 0:
      writeJsonField(s, "schema", x.schema)
    else:
      writeJsonField(s, "schema", RawJson("{}"))
    writeJsonField(s, "strict", x.strict)
  streams.write(s, "}")

proc writeJson*(s: Stream; x: ResponseTextConfig) =
  var comma = false
  streams.write(s, "{")
  writeJsonField(s, "format", x.format)
  if x.verbosity.len > 0:
    writeJsonField(s, "verbosity", x.verbosity)
  streams.write(s, "}")

proc writeJson*(s: Stream; x: ResponseReasoning) =
  var comma = false
  streams.write(s, "{")
  if x.effort != ResponseReasoningEffort.unspecified:
    writeJsonField(s, "effort", x.effort)
  if x.summary.len > 0:
    writeJsonField(s, "summary", x.summary)
  if x.mode.len > 0:
    writeJsonField(s, "mode", x.mode)
  if x.context.len > 0:
    writeJsonField(s, "context", x.context)
  streams.write(s, "}")

proc writeJson*(s: Stream; x: ResponsePromptCacheOptions) =
  var comma = false
  streams.write(s, "{")
  if x.mode.len > 0:
    writeJsonField(s, "mode", x.mode)
  if x.ttl.len > 0:
    writeJsonField(s, "ttl", x.ttl)
  streams.write(s, "}")

proc hasPromptCacheOptions(x: ResponsePromptCacheOptions): bool {.inline.} =
  x.mode.len > 0 or x.ttl.len > 0

proc hasReasoning(x: ResponseReasoning): bool {.inline.} =
  x.effort != ResponseReasoningEffort.unspecified or x.summary.len > 0 or
    x.mode.len > 0 or x.context.len > 0

proc hasTextConfig(x: ResponseTextConfig): bool {.inline.} =
  x.format.`type` == ResponseTextFormatType.json_schema or x.verbosity.len > 0

proc writeJson*(s: Stream; x: OpenAIResponseIn) =
  var comma = false
  streams.write(s, "{")
  writeJsonField(s, "model", x.model)
  writeJsonField(s, "input", x.input)
  if x.background: writeJsonField(s, "background", x.background)
  if x.context_management.len > 0:
    writeJsonField(s, "context_management", x.context_management)
  if x.conversation.len > 0: writeJsonField(s, "conversation", x.conversation)
  if x.`include`.len > 0: writeJsonField(s, "include", x.`include`)
  if x.instructions.len > 0: writeJsonField(s, "instructions", x.instructions)
  if x.max_output_tokens > 0: writeJsonField(s, "max_output_tokens", x.max_output_tokens)
  if x.max_tool_calls > 0: writeJsonField(s, "max_tool_calls", x.max_tool_calls)
  if string(x.metadata).len > 0: writeJsonField(s, "metadata", x.metadata)
  if string(x.moderation).len > 0: writeJsonField(s, "moderation", x.moderation)
  if not x.parallel_tool_calls:
    writeJsonField(s, "parallel_tool_calls", x.parallel_tool_calls)
  if x.previous_response_id.len > 0:
    writeJsonField(s, "previous_response_id", x.previous_response_id)
  if string(x.prompt).len > 0: writeJsonField(s, "prompt", x.prompt)
  if x.prompt_cache_key.len > 0: writeJsonField(s, "prompt_cache_key", x.prompt_cache_key)
  if x.prompt_cache_options.hasPromptCacheOptions():
    writeJsonField(s, "prompt_cache_options", x.prompt_cache_options)
  if x.reasoning.hasReasoning(): writeJsonField(s, "reasoning", x.reasoning)
  if x.safety_identifier.len > 0:
    writeJsonField(s, "safety_identifier", x.safety_identifier)
  if x.service_tier.len > 0: writeJsonField(s, "service_tier", x.service_tier)
  if not x.store: writeJsonField(s, "store", x.store)
  if x.stream: writeJsonField(s, "stream", x.stream)
  if string(x.stream_options).len > 0:
    writeJsonField(s, "stream_options", x.stream_options)
  if x.temperature != 1.0: writeJsonField(s, "temperature", x.temperature)
  if x.text.hasTextConfig(): writeJsonField(s, "text", x.text)
  if string(x.tool_choice).len > 0: writeJsonField(s, "tool_choice", x.tool_choice)
  if x.tools.len > 0: writeJsonField(s, "tools", x.tools)
  if x.top_logprobs > 0: writeJsonField(s, "top_logprobs", x.top_logprobs)
  if x.top_p != 1.0: writeJsonField(s, "top_p", x.top_p)
  streams.write(s, "}")
