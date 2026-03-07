import jsonx
import jsonx/streams

type
  OpenAIEmbeddingsUsage* = object
    prompt_tokens*: int
    total_tokens*: int

  OpenAIEmbeddingData* = object
    `object`*: string
    index*: int
    embedding*: seq[float]

  OpenAIEmbeddingsIn* = object
    model*: string
    input*: string
    encoding_format*: string

  OpenAIEmbeddingsOut* = object
    `object`*: string
    data*: seq[OpenAIEmbeddingData]
    model*: string
    usage*: OpenAIEmbeddingsUsage

template writeJsonField(s: Stream; name: string; value: untyped) =
  if comma: streams.write(s, ",")
  else: comma = true
  escapeJson(s, name)
  streams.write(s, ":")
  writeJson(s, value)

proc writeJson*(s: Stream; x: OpenAIEmbeddingsIn) =
  var comma = false
  streams.write(s, "{")
  writeJsonField(s, "model", x.model)
  writeJsonField(s, "input", x.input)
  if x.encoding_format.len > 0:
    writeJsonField(s, "encoding_format", x.encoding_format)
  streams.write(s, "}")
