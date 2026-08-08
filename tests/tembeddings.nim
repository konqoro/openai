import relay
import jsonx
import openai/embeddings

const GoodResponse = """{
  "object": "list",
  "data": [
    {
      "object": "embedding",
      "index": 0,
      "embedding": [0.1, 0.2, 0.3]
    }
  ],
  "model": "Qwen/Qwen3-Embedding-0.6B",
  "usage": {
    "prompt_tokens": 7,
    "total_tokens": 7
  }
}"""

const Base64Response = """{
  "object": "list",
  "data": [
    {
      "object": "embedding",
      "index": 0,
      "embedding": "AQID"
    }
  ],
  "model": "Qwen/Qwen3-Embedding-0.6B",
  "usage": {
    "prompt_tokens": 7,
    "total_tokens": 7
  }
}"""

template expectValueError(body: untyped) =
  var raised = false
  try:
    discard body
  except ValueError:
    raised = true
  doAssert raised

proc sampleConfig(apiKey = "sk-test"): OpenAIConfig =
  OpenAIConfig(
    url: OpenAIBaseUrl,
    apiKey: apiKey
  )

proc testEmbeddingRequest() =
  let cfg = sampleConfig(apiKey = "new-token")
  var headers = emptyHttpHeaders()
  headers["Authorization"] = "Bearer old-token"
  headers["Content-Type"] = "text/plain"
  headers["X-Trace-Id"] = "trace-1"

  let req = embeddingRequest(
    cfg,
    embeddingCreate(
      model = "Qwen/Qwen3-Embedding-0.6B",
      input = "hello",
      encodingFormat = EmbeddingEncodingFormat.`float`
    ),
    requestId = 42,
    timeoutMs = 7_000,
    headers = move headers
  )

  doAssert req.verb == hvPost
  doAssert req.url == cfg.url & "/embeddings"
  doAssert req.requestId == 42
  doAssert req.timeoutMs == 7_000
  doAssert req.headers["Authorization"] == "Bearer new-token"
  doAssert req.headers["Content-Type"] == "application/json"
  doAssert req.headers["X-Trace-Id"] == "trace-1"
  doAssert req.body ==
    """{"model":"Qwen/Qwen3-Embedding-0.6B","input":"hello"}"""

proc testEmbeddingEncodingFormatEnum() =
  let params = embeddingCreate("m", "text", EmbeddingEncodingFormat.base64)
  doAssert toJson(params) ==
    """{"model":"m","input":"text","encoding_format":"base64"}"""

proc testEmbeddingInputKinds() =
  doAssert toJson(embeddingCreate("m", embeddingInputTexts(@["one", "two"]),
    dimensions = 256, user = "user-1")) ==
    """{"model":"m","input":["one","two"],"dimensions":256,"user":"user-1"}"""
  doAssert toJson(embeddingCreate("m", embeddingInputTokens(@[1, 2, 3]))) ==
    """{"model":"m","input":[1,2,3]}"""
  doAssert toJson(embeddingCreate("m",
    embeddingInputTokenArrays(@[@[1, 2], @[3, 4]]))) ==
    """{"model":"m","input":[[1,2],[3,4]]}"""

proc testEmbeddingBatchAdd() =
  let cfg = sampleConfig()
  var batch: RequestBatch
  embeddingAdd(batch, cfg, embeddingCreate("m", "text"), requestId = 11, timeoutMs = 1500)

  doAssert batch.len == 1
  doAssert batch[0].requestId == 11
  doAssert batch[0].timeoutMs == 1500
  doAssert batch[0].verb == hvPost

proc testEmbeddingParseAndAccessors() =
  var parsed: EmbeddingCreateResult
  doAssert embeddingParse(GoodResponse, parsed)
  doAssert outputItems(parsed) == 1
  doAssert modelOf(parsed) == "Qwen/Qwen3-Embedding-0.6B"
  doAssert inputTokens(parsed) == 7
  doAssert totalTokens(parsed) == 7
  doAssert embedding(parsed).len == 3
  doAssert embedding(parsed)[1] == 0.2'f32
  expectValueError embedding(parsed, 1)

proc testBase64EmbeddingParseAndAccessors() =
  var parsed: EmbeddingCreateResult
  doAssert embeddingParse(Base64Response, parsed)
  doAssert outputItems(parsed) == 1
  doAssert parsed.data[0].embedding.kind == EmbeddingContentKind.encoded
  doAssert embeddingBase64(parsed) == "AQID"
  expectValueError embedding(parsed)
  expectValueError embeddingBase64(parsed, 1)

proc testEmbeddingParseFailure() =
  var parsed: EmbeddingCreateResult
  doAssert not embeddingParse("{bad json", parsed)

when isMainModule:
  testEmbeddingRequest()
  testEmbeddingBatchAdd()
  testEmbeddingEncodingFormatEnum()
  testEmbeddingInputKinds()
  testEmbeddingParseAndAccessors()
  testBase64EmbeddingParseAndAccessors()
  testEmbeddingParseFailure()
