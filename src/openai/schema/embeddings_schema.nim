## JSON-mapped types for the OpenAI Embeddings API.

import jsonx
import jsonx/[parsejson, streams]

type
  EmbeddingFormat* = enum
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

  EmbeddingValueKind* = enum
    values, encoded

  EmbeddingUsage* = object
    prompt_tokens*: int
    total_tokens*: int

  EmbeddingValue* = object
    case kind*: EmbeddingValueKind
    of values:
      values*: seq[float32]
    of encoded:
      encoded*: string

  EmbeddingItem* = object
    `object`*: string
    index*: int
    embedding*: EmbeddingValue

  EmbeddingParams* = object
    model*: string
    input*: EmbeddingInput
    encoding_format*: EmbeddingFormat
    dimensions*: int
    user*: string

  EmbeddingResult* = object
    `object`*: string
    data*: seq[EmbeddingItem]
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

proc writeJson*(s: Stream; x: EmbeddingParams) =
  var comma = false
  streams.write(s, "{")
  writeJsonField(s, "model", x.model)
  writeJsonField(s, "input", x.input)
  if x.encoding_format != EmbeddingFormat.float:
    writeJsonField(s, "encoding_format", x.encoding_format)
  if x.dimensions > 0:
    writeJsonField(s, "dimensions", x.dimensions)
  if x.user.len > 0:
    writeJsonField(s, "user", x.user)
  streams.write(s, "}")

proc readJson*(dst: var EmbeddingValue; p: var JsonParser;
    unknownFields: UnknownFieldPolicy) =
  if p.tok == tkString:
    dst = EmbeddingValue(kind: encoded)
    readJson(dst.encoded, p, unknownFields)
  elif p.tok == tkBracketLe:
    dst = EmbeddingValue(kind: values)
    readJson(dst.values, p, unknownFields)
  else:
    raiseParseErr(p, "string or array")

proc writeJson*(s: Stream; x: EmbeddingValue) =
  case x.kind
  of values:
    writeJson(s, x.values)
  of encoded:
    writeJson(s, x.encoded)
