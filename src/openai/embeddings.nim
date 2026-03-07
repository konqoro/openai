import relay
import jsonx
import ./[core, http]
import ./schema/embeddings_schema

export core
export embeddings_schema

const OpenAIEmbeddingsUrl* = "https://api.openai.com/v1/embeddings"

type
  EmbeddingCreateParams* = OpenAIEmbeddingsIn
  EmbeddingCreateResult* = OpenAIEmbeddingsOut

proc embeddingCreate*(model, input: sink string;
    encodingFormat = EmbeddingEncodingFormat.`float`): EmbeddingCreateParams =
  EmbeddingCreateParams(
    model: model,
    input: input,
    encoding_format: encodingFormat
  )

proc embeddingRequest*(cfg: OpenAIConfig; params: EmbeddingCreateParams;
    requestId = 0'i64; timeoutMs = 0;
    headers: sink HttpHeaders = emptyHttpHeaders()): RequestSpec =
  jsonPostRequest(cfg, params, requestId, timeoutMs, headers)

proc embeddingAdd*(batch: var RequestBatch; cfg: OpenAIConfig;
    params: EmbeddingCreateParams; requestId = 0'i64; timeoutMs = 0;
    headers: sink HttpHeaders = emptyHttpHeaders()) =
  jsonPostAdd(batch, cfg, params, requestId, timeoutMs, headers)

proc embeddingParse*(body: string; dst: var EmbeddingCreateResult): bool =
  try:
    dst = fromJson(body, EmbeddingCreateResult)
    result = true
  except CatchableError:
    result = false

proc embeddings*(x: EmbeddingCreateResult): int {.inline.} =
  result = x.data.len

proc raiseAccessorValueError(message: string) {.noinline, noreturn.} =
  raise newException(ValueError, message)

proc ensureEmbeddingIndex(embeddingCount, i: int) {.inline.} =
  if i < 0 or i >= embeddingCount:
    raiseAccessorValueError("embedding index " & $i &
      " out of range for " & $embeddingCount & " embeddings")

proc ensureFloatEmbedding(x: OpenAIEmbeddingContent; i: int) {.inline.} =
  if x.kind != EmbeddingContentKind.values:
    raiseAccessorValueError("embedding " & $i &
      " uses base64 encoding; request float encoding or use embeddingBase64()")

proc ensureBase64Embedding(x: OpenAIEmbeddingContent; i: int) {.inline.} =
  if x.kind != EmbeddingContentKind.encoded:
    raiseAccessorValueError("embedding " & $i &
      " uses float encoding; use embedding() for numeric vectors")

proc embedding*(x: EmbeddingCreateResult; i = 0): lent seq[float32] {.inline.} =
  ensureEmbeddingIndex(x.data.len, i)
  ensureFloatEmbedding(x.data[i].embedding, i)
  result = x.data[i].embedding.values

proc embedding*(x: var EmbeddingCreateResult; i = 0): var seq[float32] {.inline.} =
  ensureEmbeddingIndex(x.data.len, i)
  ensureFloatEmbedding(x.data[i].embedding, i)
  result = x.data[i].embedding.values

proc embeddingBase64*(x: EmbeddingCreateResult; i = 0): lent string {.inline.} =
  ensureEmbeddingIndex(x.data.len, i)
  ensureBase64Embedding(x.data[i].embedding, i)
  result = x.data[i].embedding.encoded

proc embeddingBase64*(x: var EmbeddingCreateResult; i = 0): var string {.inline.} =
  ensureEmbeddingIndex(x.data.len, i)
  ensureBase64Embedding(x.data[i].embedding, i)
  result = x.data[i].embedding.encoded

proc modelOf*(x: EmbeddingCreateResult): lent string {.inline.} =
  result = x.model

proc modelOf*(x: var EmbeddingCreateResult): var string {.inline.} =
  result = x.model

proc promptTokens*(x: EmbeddingCreateResult): int {.inline.} =
  result = x.usage.prompt_tokens

proc totalTokens*(x: EmbeddingCreateResult): int {.inline.} =
  result = x.usage.total_tokens
