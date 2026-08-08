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

proc readJson*(dst: var EmbeddingContent; p: var JsonParser) =
  if p.tok == tkString:
    dst = EmbeddingContent(kind: encoded)
    readJson(dst.encoded, p)
  elif p.tok == tkBracketLe:
    dst = EmbeddingContent(kind: values)
    readJson(dst.values, p)
  else:
    raiseParseErr(p, "string or array")

proc writeJson*(s: Stream; x: EmbeddingContent) =
  case x.kind
  of values:
    writeJson(s, x.values)
  of encoded:
    writeJson(s, x.encoded)

template readObjectFields(p: var JsonParser; body: untyped) =
  eat(p, tkCurlyLe)
  while p.tok != tkCurlyRi:
    if p.tok != tkString:
      raiseParseErr(p, "string literal as key")
    let fieldName {.inject.} = p.a
    discard getTok(p)
    eat(p, tkColon)
    body
    if p.tok == tkComma:
      discard getTok(p)
    elif p.tok != tkCurlyRi:
      raiseParseErr(p, "comma or closing brace")
  eat(p, tkCurlyRi)

proc readJson*(dst: var EmbeddingData; p: var JsonParser) =
  readObjectFields(p):
    case fieldName
    of "object": readJson(dst.`object`, p)
    of "index": readJson(dst.index, p)
    of "embedding": readJson(dst.embedding, p)
    else: skipJson(p)

proc readJson*(dst: var EmbeddingUsage; p: var JsonParser) =
  readObjectFields(p):
    case fieldName
    of "prompt_tokens": readJson(dst.prompt_tokens, p)
    of "total_tokens": readJson(dst.total_tokens, p)
    else: skipJson(p)

proc readJson*(dst: var OpenAIEmbeddingOut; p: var JsonParser) =
  readObjectFields(p):
    case fieldName
    of "object": readJson(dst.`object`, p)
    of "data": readJson(dst.data, p)
    of "model": readJson(dst.model, p)
    of "usage": readJson(dst.usage, p)
    else: skipJson(p)
