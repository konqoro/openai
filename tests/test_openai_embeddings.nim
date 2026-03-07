import relay
import openai, openai_embeddings

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

template expectValueError(body: untyped) =
  var raised = false
  try:
    discard body
  except ValueError:
    raised = true
  doAssert raised

proc sampleConfig(apiKey = "sk-test"): OpenAIConfig =
  OpenAIConfig(
    url: "https://api.openai.com/v1/embeddings",
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
      encodingFormat = "float"
    ),
    requestId = 42,
    timeoutMs = 7_000,
    headers = move headers
  )

  doAssert req.verb == hvPost
  doAssert req.url == cfg.url
  doAssert req.requestId == 42
  doAssert req.timeoutMs == 7_000
  doAssert req.headers["Authorization"] == "Bearer new-token"
  doAssert req.headers["Content-Type"] == "application/json"
  doAssert req.headers["X-Trace-Id"] == "trace-1"
  doAssert req.body ==
    """{"model":"Qwen/Qwen3-Embedding-0.6B","input":"hello","encoding_format":"float"}"""

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
  doAssert embeddings(parsed) == 1
  doAssert modelOf(parsed) == "Qwen/Qwen3-Embedding-0.6B"
  doAssert promptTokens(parsed) == 7
  doAssert totalTokens(parsed) == 7
  doAssert embedding(parsed).len == 3
  doAssert embedding(parsed)[1] == 0.2
  expectValueError embedding(parsed, 1)

proc testEmbeddingParseFailure() =
  var parsed: EmbeddingCreateResult
  doAssert not embeddingParse("{bad json", parsed)

when isMainModule:
  testEmbeddingRequest()
  testEmbeddingBatchAdd()
  testEmbeddingParseAndAccessors()
  testEmbeddingParseFailure()
