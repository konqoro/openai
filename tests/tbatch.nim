import std/strutils
import relay
import jsonx
import openai/batch

const CompletedBatchResponse = """{
  "id": "batch_abc123",
  "object": "batch",
  "endpoint": "/v1/chat/completions",
  "errors": null,
  "input_file_id": "file-abc123",
  "completion_window": "24h",
  "status": "completed",
  "output_file_id": "file-cvaTdG",
  "error_file_id": "file-HOWS94",
  "created_at": 1711471533,
  "in_progress_at": 1711471538,
  "expires_at": 1711557933,
  "finalizing_at": 1711493133,
  "completed_at": 1711493163,
  "failed_at": null,
  "expired_at": null,
  "cancelling_at": null,
  "cancelled_at": null,
  "request_counts": {
    "total": 100,
    "completed": 95,
    "failed": 5
  },
  "usage": {
    "input_tokens": 1000,
    "input_tokens_details": {"cached_tokens": 960},
    "output_tokens": 200,
    "output_tokens_details": {"reasoning_tokens": 0},
    "total_tokens": 1200
  },
  "metadata": {
    "customer_id": "user_123456789"
  }
}"""

const ValidatingBatchResponse = """{
  "id": "batch_xyz789",
  "object": "batch",
  "endpoint": "/v1/chat/completions",
  "errors": null,
  "input_file_id": "file-abc123",
  "completion_window": "24h",
  "status": "validating",
  "created_at": 1711471533
}"""

const BatchListResponse = """{
  "object": "list",
  "data": [""" & CompletedBatchResponse & """],
  "first_id": "batch_abc123",
  "last_id": "batch_abc456",
  "has_more": true
}"""

const OutputLineSuccess = """{"id":"batch_req_123","custom_id":"request-2","response":{"status_code":200,"request_id":"req_123","body":{"id":"chatcmpl-123","object":"chat.completion","created":1711652795,"model":"gpt-5.6-luna","choices":[{"index":0,"message":{"role":"assistant","content":"Hello."},"finish_reason":"stop"}],"usage":{"prompt_tokens":22,"completion_tokens":2,"total_tokens":24}}},"error":null}"""

const OutputLineError = """{"id":"batch_req_123","custom_id":"request-3","response":null,"error":{"code":"batch_expired","message":"This request could not be executed before the completion window expired."}}"""

proc sampleConfig(apiKey = "sk-test"): OpenAIConfig =
  OpenAIConfig(
    url: OpenAIBatchesUrl,
    apiKey: apiKey
  )

proc testBatchCreate() =
  let params = batchCreate(
    inputFileId = "file-abc123",
    endpoint = "/v1/chat/completions"
  )
  doAssert toJson(params) ==
    """{"input_file_id":"file-abc123","endpoint":"/v1/chat/completions","completion_window":"24h"}"""

  let withMetadata = batchCreate(
    inputFileId = "file-abc123",
    endpoint = "/v1/chat/completions",
    metadata = RawJson("""{"run":"r1"}""")
  )
  doAssert toJson(withMetadata) ==
    """{"input_file_id":"file-abc123","endpoint":"/v1/chat/completions","completion_window":"24h","metadata":{"run":"r1"}}"""

  var withExpiry = withMetadata
  withExpiry.output_expires_after = some(outputExpiresAfter(2592000))
  doAssert toJson(withExpiry) ==
    """{"input_file_id":"file-abc123","endpoint":"/v1/chat/completions","completion_window":"24h","metadata":{"run":"r1"},"output_expires_after":{"anchor":"created_at","seconds":2592000}}"""

proc testBatchRequestBuilders() =
  let cfg = sampleConfig()

  let create = batchCreateRequest(cfg, batchCreate("file-abc123",
    "/v1/chat/completions"), requestId = 2)
  doAssert create.verb == hvPost
  doAssert create.url == OpenAIBatchesUrl
  doAssert create.body ==
    """{"input_file_id":"file-abc123","endpoint":"/v1/chat/completions","completion_window":"24h"}"""

  let retrieve = batchRetrieveRequest(cfg, "batch_abc123")
  doAssert retrieve.verb == hvGet
  doAssert retrieve.url == OpenAIBatchesUrl & "/batch_abc123"

  let list = batchListRequest(cfg, after = "batch_abc", limit = 20)
  doAssert list.verb == hvGet
  doAssert list.url == OpenAIBatchesUrl & "?after=batch_abc&limit=20"

  let cancel = batchCancelRequest(cfg, "batch_abc123")
  doAssert cancel.verb == hvPost
  doAssert cancel.url == OpenAIBatchesUrl & "/batch_abc123/cancel"
  doAssert cancel.body.len == 0

proc testInputLineJson() =
  let line = batchInputLineJson(
    "request-1",
    RawJson("""{"model":"gpt-5.6-luna","messages":[{"role":"user","content":"hi"}]}""")
  )
  doAssert line ==
    """{"custom_id":"request-1","method":"POST","url":"/v1/chat/completions","body":{"model":"gpt-5.6-luna","messages":[{"role":"user","content":"hi"}]}}"""

  let parsed = fromJson(line, BatchInputLine)
  doAssert parsed.custom_id == "request-1"
  doAssert parsed.`method` == "POST"
  doAssert parsed.url == "/v1/chat/completions"
  doAssert string(parsed.body).contains("gpt-5.6-luna")

proc testBatchParseAndAccessors() =
  var parsed: Batch
  doAssert batchParse(CompletedBatchResponse, parsed)
  doAssert idOf(parsed) == "batch_abc123"
  doAssert statusOf(parsed) == BatchStatus.completed
  doAssert isTerminal(parsed)
  doAssert modelOf(parsed) == ""
  doAssert inputFileId(parsed) == "file-abc123"
  doAssert outputFileId(parsed) == "file-cvaTdG"
  doAssert errorFileId(parsed) == "file-HOWS94"
  doAssert totalRequests(parsed) == 100
  doAssert completedRequests(parsed) == 95
  doAssert failedRequests(parsed) == 5
  doAssert inputTokens(parsed) == 1000
  doAssert outputTokens(parsed) == 200
  doAssert totalTokens(parsed) == 1200
  doAssert cachedInputTokens(parsed) == 960
  doAssert reasoningOutputTokens(parsed) == 0
  doAssert parsed.completed_at.isSome
  doAssert parsed.completed_at.get == 1711493163
  doAssert parsed.failed_at.isNone
  doAssert parsed.metadata.isSome

  var validating: Batch
  doAssert batchParse(ValidatingBatchResponse, validating)
  doAssert statusOf(validating) == BatchStatus.validating
  doAssert not isTerminal(validating)

proc testBatchParseFailure() =
  var parsed: Batch
  doAssert not batchParse("{bad json", parsed)

proc testBatchListParse() =
  var parsed: BatchList
  doAssert batchListParse(BatchListResponse, parsed)
  doAssert parsed.data.len == 1
  doAssert parsed.has_more
  doAssert parsed.first_id.isSome
  doAssert idOf(parsed.data[0]) == "batch_abc123"

proc testOutputLineParse() =
  var ok: BatchOutputLine
  doAssert batchOutputLineParse(OutputLineSuccess, ok)
  doAssert ok.custom_id == "request-2"
  doAssert ok.response.isSome
  doAssert ok.error.isNone
  doAssert outputStatusCode(ok) == 200
  doAssert outputRequestId(ok) == "req_123"
  doAssert outputBody(ok).contains("chatcmpl-123")
  doAssert outputBody(ok).contains("gpt-5.6-luna")

  var err: BatchOutputLine
  doAssert batchOutputLineParse(OutputLineError, err)
  doAssert err.custom_id == "request-3"
  doAssert err.response.isNone
  doAssert err.error.isSome
  doAssert outputErrorCode(err) == "batch_expired"
  doAssert outputErrorMessage(err).contains("completion window")

when isMainModule:
  testBatchCreate()
  testBatchRequestBuilders()
  testInputLineJson()
  testBatchParseAndAccessors()
  testBatchParseFailure()
  testBatchListParse()
  testOutputLineParse()
