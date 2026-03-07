import jsonx
import jsonx/[parsejson, streams]

type
  EmbeddingEncodingFormat* = enum
    `float`, base64

  EmbeddingContentKind* = enum
    values, encoded

  OpenAIEmbeddingsUsage* = object
    prompt_tokens*: int
    total_tokens*: int

  OpenAIEmbeddingContent* = object
    case kind*: EmbeddingContentKind
    of values:
      values*: seq[float32]
    of encoded:
      encoded*: string

  OpenAIEmbeddingData* = object
    `object`*: string
    index*: int
    embedding*: OpenAIEmbeddingContent

  OpenAIEmbeddingsIn* = object
    model*: string
    input*: string
    encoding_format*: EmbeddingEncodingFormat

  OpenAIEmbeddingsOut* = object
    `object`*: string
    data*: seq[OpenAIEmbeddingData]
    model*: string
    usage*: OpenAIEmbeddingsUsage

proc readJson*(dst: var OpenAIEmbeddingContent; p: var JsonParser) =
  if p.tok == tkString:
    dst = OpenAIEmbeddingContent(kind: encoded)
    readJson(dst.encoded, p)
  elif p.tok == tkBracketLe:
    dst = OpenAIEmbeddingContent(kind: values)
    readJson(dst.values, p)
  else:
    raiseParseErr(p, "string or array")

proc writeJson*(s: Stream; x: OpenAIEmbeddingContent) =
  case x.kind
  of values:
    writeJson(s, x.values)
  of encoded:
    writeJson(s, x.encoded)
