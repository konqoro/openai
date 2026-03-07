import relay
import jsonx
import openai
import openai_embeddings_schema

export openai_embeddings_schema

const OpenAIEmbeddingsUrl* = "https://api.openai.com/v1/embeddings"

type
  EmbeddingCreateParams* = OpenAIEmbeddingsIn
  EmbeddingCreateResult* = OpenAIEmbeddingsOut

proc withDefaultHeaders(cfg: OpenAIConfig;
    headers: sink HttpHeaders = emptyHttpHeaders()): HttpHeaders =
  result = headers
  result["Authorization"] = "Bearer " & cfg.apiKey
  result["Content-Type"] = "application/json"

proc embeddingCreate*(model, input: sink string;
    encodingFormat = "float"): EmbeddingCreateParams =
  EmbeddingCreateParams(
    model: model,
    input: input,
    encoding_format: encodingFormat
  )

proc embeddingRequest*(cfg: OpenAIConfig; params: EmbeddingCreateParams;
    requestId = 0'i64; timeoutMs = 0;
    headers: sink HttpHeaders = emptyHttpHeaders()): RequestSpec =
  RequestSpec(
    verb: hvPost,
    url: cfg.url,
    headers: cfg.withDefaultHeaders(headers),
    body: toJson(params),
    requestId: requestId,
    timeoutMs: timeoutMs
  )

proc embeddingAdd*(batch: var RequestBatch; cfg: OpenAIConfig;
    params: EmbeddingCreateParams; requestId = 0'i64; timeoutMs = 0;
    headers: sink HttpHeaders = emptyHttpHeaders()) =
  batch.addRequest(
    verb = hvPost,
    url = cfg.url,
    headers = cfg.withDefaultHeaders(headers),
    body = toJson(params),
    requestId = requestId,
    timeoutMs = timeoutMs
  )

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

proc embedding*(x: EmbeddingCreateResult; i = 0): lent seq[float] {.inline.} =
  ensureEmbeddingIndex(x.data.len, i)
  result = x.data[i].embedding

proc embedding*(x: var EmbeddingCreateResult; i = 0): var seq[float] {.inline.} =
  ensureEmbeddingIndex(x.data.len, i)
  result = x.data[i].embedding

proc modelOf*(x: EmbeddingCreateResult): lent string {.inline.} =
  result = x.model

proc modelOf*(x: var EmbeddingCreateResult): var string {.inline.} =
  result = x.model

proc promptTokens*(x: EmbeddingCreateResult): int {.inline.} =
  result = x.usage.prompt_tokens

proc totalTokens*(x: EmbeddingCreateResult): int {.inline.} =
  result = x.usage.total_tokens
