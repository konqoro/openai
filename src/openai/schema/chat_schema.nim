import std/options
export options
import jsonx
import jsonx/[parsejson, streams]

type
  ChatMessageRole* = enum
    system, developer, user, assistant, tool

  ChatToolType* = enum
    function

  ChatFinishReason* = enum
    stop, length, tool_calls, content_filter

  ChatImageDetail* = enum
    `auto`, low, high

  ChatInputAudioFormat* = enum
    wav, mp3

  ChatReasoningEffort* = enum
    unspecified = ""
    none = "none"
    minimal = "minimal"
    low = "low"
    medium = "medium"
    high = "high"
    xhigh = "xhigh"
    max = "max"

  ChatResponseFormatType* = enum
    text, json_object, json_schema

  ChatCompletionAssistantContentKind* = enum
    none, text, parts

  ChatCompletionContentPartText* = object
    `type`*: ChatCompletionContentPartType
    text*: string

  ChatFunctionCall* = object
    name*: string
    arguments*: string

  ChatCompletionMessageToolCall* = object
    id*: string
    `type`*: ChatToolType
    function*: ChatFunctionCall

  ChatCompletionAssistantContent* = object
    case kind*: ChatCompletionAssistantContentKind
    of none:
      discard
    of text:
      text*: string
    of parts:
      parts*: seq[ChatCompletionContentPartText]

  ChatCompletionAssistantMessage* = object
    role*: ChatMessageRole
    tool_calls*: seq[ChatCompletionMessageToolCall]
    content*: ChatCompletionAssistantContent
    refusal*: Option[string]
    annotations*: seq[RawJson]

  OpenAIChatCompletionChoice* = object
    index*: int
    message*: ChatCompletionAssistantMessage
    finish_reason*: ChatFinishReason

  ChatPromptTokensDetails* = object
    cached_tokens*: int
    cache_write_tokens*: int
    audio_tokens*: int

  ChatCompletionTokensDetails* = object
    reasoning_tokens*: int
    audio_tokens*: int
    accepted_prediction_tokens*: int
    rejected_prediction_tokens*: int

  ChatUsage* = object
    prompt_tokens*: int
    completion_tokens*: int
    total_tokens*: int
    prompt_tokens_details*: ChatPromptTokensDetails
    completion_tokens_details*: ChatCompletionTokensDetails

  OpenAIChatCompletionOut* = object
    id*: string
    `object`*: string
    created*: int64
    model*: string
    choices*: seq[OpenAIChatCompletionChoice]
    usage*: ChatUsage
    service_tier*: string
    system_fingerprint*: Option[string]

  ChatCompletionInputContentKind* = enum
    text, parts

  ChatCompletionContentPartType* = enum
    text, image_url, input_audio

  ChatImageUrl* = object
    url*: string
    detail*: ChatImageDetail

  ChatInputAudio* = object
    data*: string
    format*: ChatInputAudioFormat

  ChatCompletionContentPart* = object
    case `type`*: ChatCompletionContentPartType
    of text:
      text*: string
    of image_url:
      image_url*: ChatImageUrl
    of input_audio:
      input_audio*: ChatInputAudio

  ChatCompletionMessageContent* = object
    case kind*: ChatCompletionInputContentKind
    of text:
      text*: string
    of parts:
      parts*: seq[ChatCompletionContentPart]

  ChatFunctionDefinition* = object
    name*: string
    description*: string
    parameters*: RawJson
    strict*: bool

  ChatTool* = object
    `type`*: ChatToolType
    function*: ChatFunctionDefinition

  ChatResponseFormatJsonSchema* = object
    name*: string
    description*: string
    schema*: RawJson
    strict*: bool

  ChatResponseFormat* = object
    `type`*: ChatResponseFormatType
    json_schema*: ChatResponseFormatJsonSchema

  ChatPromptCacheOptions* = object
    mode*: string
    ttl*: string

  ChatMessage* = object
    role*: ChatMessageRole
    content*: ChatCompletionMessageContent
    tool_calls*: seq[ChatCompletionMessageToolCall]
    name*: string
    tool_call_id*: string

  OpenAIChatCompletionsIn* = object
    model*: string
    messages*: seq[ChatMessage]
    stream*: bool
    temperature*: float = 1.0
    max_completion_tokens*: int
    reasoning_effort*: ChatReasoningEffort
    tools*: seq[ChatTool]
    tool_choice*: RawJson
    response_format*: ChatResponseFormat
    parallel_tool_calls*: bool = true
    metadata*: RawJson
    prompt_cache_key*: string
    prompt_cache_options*: ChatPromptCacheOptions
    safety_identifier*: string
    service_tier*: string
    store*: bool

const
  EmptyFunctionParametersSchema* = RawJson("""{"type":"object","properties":{}}""")
  ChatToolChoiceAuto* = RawJson("\"auto\"")
  ChatToolChoiceNone* = RawJson("\"none\"")
  ChatToolChoiceRequired* = RawJson("\"required\"")

proc readJson*(dst: var ChatCompletionAssistantContent; p: var JsonParser;
    unknownFields: UnknownFieldPolicy) =
  case p.tok
  of tkNull:
    dst = ChatCompletionAssistantContent(kind: none)
    discard getTok(p)
  of tkString:
    dst = ChatCompletionAssistantContent(kind: text)
    readJson(dst.text, p, unknownFields)
  of tkBracketLe:
    dst = ChatCompletionAssistantContent(kind: parts)
    readJson(dst.parts, p, unknownFields)
  else:
    raiseParseErr(p, "string, array, or null")

proc readJson*(dst: var ChatCompletionMessageContent; p: var JsonParser;
    unknownFields: UnknownFieldPolicy) =
  if p.tok == tkString:
    dst = ChatCompletionMessageContent(kind: text)
    readJson(dst.text, p, unknownFields)
  elif p.tok == tkBracketLe:
    dst = ChatCompletionMessageContent(kind: parts)
    readJson(dst.parts, p, unknownFields)
  else:
    raiseParseErr(p, "string or array")

proc writeJson*(s: Stream; x: ChatCompletionAssistantContent) =
  case x.kind
  of none:
    streams.write(s, "null")
  of text:
    writeJson(s, x.text)
  of parts:
    writeJson(s, x.parts)

proc writeJson*(s: Stream; x: ChatCompletionMessageContent) =
  case x.kind
  of text:
    writeJson(s, x.text)
  of parts:
    writeJson(s, x.parts)

proc hasMessageContent(x: ChatMessage): bool =
  case x.content.kind
  of text:
    result = x.content.text.len > 0
  of parts:
    result = x.content.parts.len > 0

template writeJsonField(s: Stream; name: string; value: untyped) =
  if comma: streams.write(s, ",")
  else: comma = true
  escapeJson(s, name)
  streams.write(s, ":")
  writeJson(s, value)

proc writeJson*(s: Stream; x: ChatFunctionDefinition) =
  var comma = false
  streams.write(s, "{")
  writeJsonField(s, "name", x.name)
  if x.description.len > 0:
    writeJsonField(s, "description", x.description)
  if string(x.parameters).len > 0:
    writeJsonField(s, "parameters", x.parameters)
  else:
    writeJsonField(s, "parameters", EmptyFunctionParametersSchema)
  writeJsonField(s, "strict", x.strict)
  streams.write(s, "}")

proc writeJson*(s: Stream; x: ChatResponseFormatJsonSchema) =
  var comma = false
  streams.write(s, "{")
  writeJsonField(s, "name", x.name)
  if x.description.len > 0:
    writeJsonField(s, "description", x.description)
  if string(x.schema).len > 0:
    writeJsonField(s, "schema", x.schema)
  else:
    writeJsonField(s, "schema", RawJson("{}"))
  writeJsonField(s, "strict", x.strict)
  streams.write(s, "}")

proc writeJson*(s: Stream; x: ChatResponseFormat) =
  var comma = false
  streams.write(s, "{")
  writeJsonField(s, "type", x.`type`)
  if x.`type` == ChatResponseFormatType.json_schema:
    writeJsonField(s, "json_schema", x.json_schema)
  streams.write(s, "}")

proc writeJson*(s: Stream; x: ChatPromptCacheOptions) =
  var comma = false
  streams.write(s, "{")
  if x.mode.len > 0:
    writeJsonField(s, "mode", x.mode)
  if x.ttl.len > 0:
    writeJsonField(s, "ttl", x.ttl)
  streams.write(s, "}")

proc writeJson*(s: Stream; x: ChatMessage) =
  var comma = false
  streams.write(s, "{")
  writeJsonField(s, "role", x.role)
  if x.tool_calls.len > 0:
    writeJsonField(s, "tool_calls", x.tool_calls)
  let omitAssistantContent = x.role == ChatMessageRole.assistant and
    x.tool_calls.len > 0 and not x.hasMessageContent()
  if not omitAssistantContent:
    writeJsonField(s, "content", x.content)
  if x.name.len > 0:
    writeJsonField(s, "name", x.name)
  if x.role == ChatMessageRole.tool and x.tool_call_id.len > 0:
    writeJsonField(s, "tool_call_id", x.tool_call_id)
  streams.write(s, "}")

proc writeJson*(s: Stream; x: OpenAIChatCompletionsIn) =
  var comma = false
  streams.write(s, "{")
  writeJsonField(s, "model", x.model)
  writeJsonField(s, "messages", x.messages)
  if x.stream:
    writeJsonField(s, "stream", x.stream)
  if x.temperature != 1.0:
    writeJsonField(s, "temperature", x.temperature)
  if x.max_completion_tokens != 0:
    writeJsonField(s, "max_completion_tokens", x.max_completion_tokens)
  if x.reasoning_effort != ChatReasoningEffort.unspecified:
    writeJsonField(s, "reasoning_effort", x.reasoning_effort)
  if x.tools.len > 0:
    writeJsonField(s, "tools", x.tools)
  if string(x.tool_choice).len > 0:
    writeJsonField(s, "tool_choice", x.tool_choice)
  if x.response_format.`type` != ChatResponseFormatType.text:
    writeJsonField(s, "response_format", x.response_format)
  if not x.parallel_tool_calls:
    writeJsonField(s, "parallel_tool_calls", x.parallel_tool_calls)
  if string(x.metadata).len > 0:
    writeJsonField(s, "metadata", x.metadata)
  if x.prompt_cache_key.len > 0:
    writeJsonField(s, "prompt_cache_key", x.prompt_cache_key)
  if x.prompt_cache_options.mode.len > 0 or x.prompt_cache_options.ttl.len > 0:
    writeJsonField(s, "prompt_cache_options", x.prompt_cache_options)
  if x.safety_identifier.len > 0:
    writeJsonField(s, "safety_identifier", x.safety_identifier)
  if x.service_tier.len > 0:
    writeJsonField(s, "service_tier", x.service_tier)
  if x.store:
    writeJsonField(s, "store", x.store)
  streams.write(s, "}")
