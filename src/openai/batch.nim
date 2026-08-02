import std/strutils
import relay
import jsonx
import ./[core, http]
import ./schema/batch_schema

export core
export batch_schema

const
  OpenAIBatchesUrl* = "https://api.openai.com/v1/batches"
  BatchCompletionWindow* = "24h"

type
  BatchCreateResult* = Batch

proc listQuery(after: string; limit: int): string =
  var parts: seq[string] = @[]
  if after.len > 0:
    parts.add("after=" & after)
  if limit > 0:
    parts.add("limit=" & $limit)
  if parts.len > 0:
    result = "?" & parts.join("&")

proc batchCreate*(inputFileId, endpoint: sink string;
    completionWindow = BatchCompletionWindow;
    metadata: sink RawJson = RawJson("")): BatchCreateParams =
  result = BatchCreateParams(
    input_file_id: inputFileId,
    endpoint: endpoint,
    completion_window: completionWindow
  )
  if string(metadata).len > 0:
    result.metadata = some(metadata)

proc outputExpiresAfter*(seconds: int;
    anchor: sink string = "created_at"): OutputExpiresAfter =
  OutputExpiresAfter(anchor: anchor, seconds: seconds)

proc batchCreateRequest*(cfg: OpenAIConfig; params: BatchCreateParams;
    url = ""; requestId = 0'i64; timeoutMs = 0;
    headers: sink HttpHeaders = emptyHttpHeaders()): RequestSpec =
  let target = if url.len > 0: url else: OpenAIBatchesUrl
  jsonRequest(cfg, hvPost, target, params, requestId, timeoutMs, headers)

proc batchRetrieveRequest*(cfg: OpenAIConfig; batchId: string; url = "";
    requestId = 0'i64; timeoutMs = 0;
    headers: sink HttpHeaders = emptyHttpHeaders()): RequestSpec =
  let target = if url.len > 0: url else: OpenAIBatchesUrl & "/" & batchId
  plainRequest(cfg, hvGet, target, requestId, timeoutMs, headers)

proc batchListRequest*(cfg: OpenAIConfig; after = ""; limit = 0; url = "";
    requestId = 0'i64; timeoutMs = 0;
    headers: sink HttpHeaders = emptyHttpHeaders()): RequestSpec =
  let target = if url.len > 0: url else:
    OpenAIBatchesUrl & listQuery(after, limit)
  plainRequest(cfg, hvGet, target, requestId, timeoutMs, headers)

proc batchCancelRequest*(cfg: OpenAIConfig; batchId: string; url = "";
    requestId = 0'i64; timeoutMs = 0;
    headers: sink HttpHeaders = emptyHttpHeaders()): RequestSpec =
  let target = if url.len > 0: url else:
    OpenAIBatchesUrl & "/" & batchId & "/cancel"
  plainRequest(cfg, hvPost, target, requestId, timeoutMs, headers)

proc batchInputLine*(customId: sink string; body: sink RawJson;
    verb = "POST"; url = "/v1/chat/completions"): BatchInputLine =
  BatchInputLine(custom_id: customId, `method`: verb, url: url, body: body)

proc batchInputLineJson*(customId: sink string; body: sink RawJson;
    verb = "POST"; url = "/v1/chat/completions"): string =
  toJson(batchInputLine(customId, body, verb, url))

proc batchParse*(body: string; dst: var Batch): bool =
  try:
    dst = fromJson(body, Batch)
    result = true
  except CatchableError:
    result = false

proc batchListParse*(body: string; dst: var BatchList): bool =
  try:
    dst = fromJson(body, BatchList)
    result = true
  except CatchableError:
    result = false

proc batchOutputLineParse*(line: string; dst: var BatchOutputLine): bool =
  try:
    dst = fromJson(line, BatchOutputLine)
    result = true
  except CatchableError:
    result = false

proc idOf*(x: Batch): lent string {.inline.} =
  result = x.id

proc idOf*(x: var Batch): var string {.inline.} =
  result = x.id

proc statusOf*(x: Batch): BatchStatus {.inline.} =
  result = x.status

proc isTerminal*(x: Batch): bool {.inline.} =
  result = x.status in {
    BatchStatus.completed, BatchStatus.failed, BatchStatus.expired,
    BatchStatus.cancelled
  }

proc modelOf*(x: Batch): string {.inline.} =
  result = x.model.get("")

proc inputFileId*(x: Batch): lent string {.inline.} =
  result = x.input_file_id

proc outputFileId*(x: Batch): string {.inline.} =
  result = x.output_file_id.get("")

proc errorFileId*(x: Batch): string {.inline.} =
  result = x.error_file_id.get("")

proc totalRequests*(x: Batch): int {.inline.} =
  result = x.request_counts.get(BatchRequestCounts()).total

proc completedRequests*(x: Batch): int {.inline.} =
  result = x.request_counts.get(BatchRequestCounts()).completed

proc failedRequests*(x: Batch): int {.inline.} =
  result = x.request_counts.get(BatchRequestCounts()).failed

proc inputTokens*(x: Batch): int {.inline.} =
  result = x.usage.get(BatchUsage()).input_tokens

proc outputTokens*(x: Batch): int {.inline.} =
  result = x.usage.get(BatchUsage()).output_tokens

proc totalTokens*(x: Batch): int {.inline.} =
  result = x.usage.get(BatchUsage()).total_tokens

proc cachedInputTokens*(x: Batch): int {.inline.} =
  result = x.usage.get(BatchUsage()).
    input_tokens_details.get(BatchUsageInputDetails()).cached_tokens

proc reasoningOutputTokens*(x: Batch): int {.inline.} =
  result = x.usage.get(BatchUsage()).
    output_tokens_details.get(BatchUsageOutputDetails()).reasoning_tokens

proc outputStatusCode*(x: BatchOutputLine): int {.inline.} =
  result = x.response.get(BatchOutputResponse()).status_code

proc outputRequestId*(x: BatchOutputLine): string {.inline.} =
  result = x.response.get(BatchOutputResponse()).request_id

proc outputBody*(x: BatchOutputLine): string {.inline.} =
  result = string(x.response.get(BatchOutputResponse()).body)

proc outputErrorCode*(x: BatchOutputLine): string {.inline.} =
  result = x.error.get(BatchOutputError()).code

proc outputErrorMessage*(x: BatchOutputLine): string {.inline.} =
  result = x.error.get(BatchOutputError()).message
