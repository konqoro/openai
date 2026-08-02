import std/strutils
import relay
import jsonx
import ./[core, http]
import ./schema/batch_schema

export core
export batch_schema

const
  BatchesPath = "/batches"
  BatchCompletionWindow* = "24h"

type
  BatchCreateResult* = Batch

proc batchCreate*(inputFileId, endpoint: sink string;
    completionWindow = BatchCompletionWindow;
    metadata: sink RawJson = RawJson("")): BatchCreateParams =
  BatchCreateParams(
    input_file_id: inputFileId,
    endpoint: endpoint,
    completion_window: completionWindow,
    metadata: metadata
  )

proc outputExpiresAfter*(seconds: int;
    anchor: sink string = "created_at"): OutputExpiresAfter =
  OutputExpiresAfter(anchor: anchor, seconds: seconds)

proc batchCreateRequest*(cfg: OpenAIConfig; params: BatchCreateParams;
    requestId = 0'i64; timeoutMs = 0;
    headers: sink HttpHeaders = emptyHttpHeaders()): RequestSpec =
  request(cfg, hvPost, cfg.url & BatchesPath, params,
    requestId, timeoutMs, headers)

proc batchRetrieveRequest*(cfg: OpenAIConfig; batchId: string;
    requestId = 0'i64; timeoutMs = 0;
    headers: sink HttpHeaders = emptyHttpHeaders()): RequestSpec =
  request(cfg, hvGet, cfg.url & BatchesPath & "/" & batchId,
    requestId, timeoutMs, headers)

proc batchListRequest*(cfg: OpenAIConfig; after = ""; limit = 0;
    requestId = 0'i64; timeoutMs = 0;
    headers: sink HttpHeaders = emptyHttpHeaders()): RequestSpec =
  var params: QueryParams
  if after.len > 0:
    params["after"] = after
  if limit > 0:
    params["limit"] = $limit
  request(cfg, hvGet, cfg.url & BatchesPath & queryString(params),
    requestId, timeoutMs, headers)

proc batchCancelRequest*(cfg: OpenAIConfig; batchId: string;
    requestId = 0'i64; timeoutMs = 0;
    headers: sink HttpHeaders = emptyHttpHeaders()): RequestSpec =
  request(cfg, hvPost,
    cfg.url & BatchesPath & "/" & batchId & "/cancel",
    requestId, timeoutMs, headers)

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

proc isFailed*(x: Batch): bool {.inline.} =
  result = x.status == BatchStatus.failed

proc isExpired*(x: Batch): bool {.inline.} =
  result = x.status == BatchStatus.expired

proc isCancelled*(x: Batch): bool {.inline.} =
  result = x.status == BatchStatus.cancelled

proc createdAt*(x: Batch): int64 {.inline.} =
  result = int64(x.created_at)

proc inProgressAt*(x: Batch): int64 {.inline.} =
  result = x.in_progress_at.get(0)

proc finalizingAt*(x: Batch): int64 {.inline.} =
  result = x.finalizing_at.get(0)

proc completedAt*(x: Batch): int64 {.inline.} =
  result = x.completed_at.get(0)

proc failedAt*(x: Batch): int64 {.inline.} =
  result = x.failed_at.get(0)

proc expiredAt*(x: Batch): int64 {.inline.} =
  result = x.expired_at.get(0)

proc expiresAt*(x: Batch): int64 {.inline.} =
  result = x.expires_at.get(0)

proc cancellingAt*(x: Batch): int64 {.inline.} =
  result = x.cancelling_at.get(0)

proc cancelledAt*(x: Batch): int64 {.inline.} =
  result = x.cancelled_at.get(0)

proc errorCount*(x: Batch): int {.inline.} =
  result = x.errors.get(BatchErrors()).data.len

proc lineOf*(x: BatchError): int64 {.inline.} =
  result = x.line.get(0)

proc modelOf*(x: Batch): lent string {.inline.} =
  result = x.model

proc inputFileId*(x: Batch): lent string {.inline.} =
  result = x.input_file_id

proc outputFileId*(x: Batch): lent string {.inline.} =
  result = x.output_file_id

proc errorFileId*(x: Batch): lent string {.inline.} =
  result = x.error_file_id

proc metadataOf*(x: Batch): string {.inline.} =
  result = string(x.metadata)

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
    input_tokens_details.cached_tokens

proc reasoningOutputTokens*(x: Batch): int {.inline.} =
  result = x.usage.get(BatchUsage()).
    output_tokens_details.reasoning_tokens

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
