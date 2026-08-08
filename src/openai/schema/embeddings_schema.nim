## JSON-mapped types for the OpenAI Embeddings API.

import jsonx
import jsonx/[parsejson, streams]

type
  EmbeddingEncodingFormat* = enum
    `float`, base64

  EmbeddingInputKind* = enum
    text, texts, tokens, tokenArrays

  EmbeddingInput* = object
    case kind*: EmbeddingInputKind
    of text:
      text*: string
    of texts:
      texts*: seq[string]
    of tokens:
      tokens*: seq[int]
    of tokenArrays:
      token_arrays*: seq[seq[int]]

  EmbeddingContentKind* = enum
    values, encoded

  EmbeddingUsage* = object
    prompt_tokens*: int
    total_tokens*: int

  EmbeddingContent* = object
    case kind*: EmbeddingContentKind
    of values:
      values*: seq[float32]
    of encoded:
      encoded*: string

  EmbeddingData* = object
    `object`*: string
    index*: int
    embedding*: EmbeddingContent

  OpenAIEmbeddingIn* = object
    model*: string
    input*: EmbeddingInput
    encoding_format*: EmbeddingEncodingFormat
    dimensions*: int
    user*: string

  OpenAIEmbeddingOut* = object
    `object`*: string
    data*: seq[EmbeddingData]
    model*: string
    usage*: EmbeddingUsage

template writeJsonField(s: Stream; name: string; value: untyped) =
  if comma: streams.write(s, ",")
  else: comma = true
  escapeJson(s, name)
  streams.write(s, ":")
  writeJson(s, value)

proc writeJson*(s: Stream; x: EmbeddingInput) =
  case x.kind
  of EmbeddingInputKind.text:
    writeJson(s, x.text)
  of EmbeddingInputKind.texts:
    writeJson(s, x.texts)
  of EmbeddingInputKind.tokens:
    writeJson(s, x.tokens)
  of EmbeddingInputKind.tokenArrays:
    writeJson(s, x.token_arrays)

proc writeJson*(s: Stream; x: OpenAIEmbeddingIn) =
  var comma = false
  streams.write(s, "{")
  writeJsonField(s, "model", x.model)
  writeJsonField(s, "input", x.input)
  if x.encoding_format != EmbeddingEncodingFormat.float:
    writeJsonField(s, "encoding_format", x.encoding_format)
  if x.dimensions > 0:
    writeJsonField(s, "dimensions", x.dimensions)
  if x.user.len > 0:
    writeJsonField(s, "user", x.user)
  streams.write(s, "}")

proc readJson*(dst: var EmbeddingContent; p: var JsonParser;
    unknownFields: UnknownFieldPolicy) =
  if p.tok == tkString:
    dst = EmbeddingContent(kind: encoded)
    readJson(dst.encoded, p, unknownFields)
  elif p.tok == tkBracketLe:
    dst = EmbeddingContent(kind: values)
    readJson(dst.values, p, unknownFields)
  else:
    raiseParseErr(p, "string or array")

proc writeJson*(s: Stream; x: EmbeddingContent) =
  case x.kind
  of values:
    writeJson(s, x.values)
  of encoded:
    writeJson(s, x.encoded)
