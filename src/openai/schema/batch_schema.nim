import std/options
export options
import jsonx
import jsonx/[parsejson, streams]

type
  BatchStatus* = enum
    unknown, validating, failed, in_progress, finalizing, completed, expired,
    cancelling, cancelled

  BatchRequestCounts* = object
    total*: int
    completed*: int
    failed*: int

  BatchUsageInputDetails* = object
    cached_tokens*: int

  BatchUsageOutputDetails* = object
    reasoning_tokens*: int

  BatchUsage* = object
    input_tokens*: int
    input_tokens_details*: BatchUsageInputDetails
    output_tokens*: int
    output_tokens_details*: BatchUsageOutputDetails
    total_tokens*: int

  BatchError* = object
    code*: string
    line*: Option[int]
    message*: string
    param*: Option[string]

  BatchErrors* = object
    `object`*: string
    data*: seq[BatchError]

  Batch* = object
    id*: string
    completion_window*: string
    created_at*: int64
    endpoint*: string
    input_file_id*: string
    `object`*: string
    status*: BatchStatus
    cancelled_at*: Option[int64]
    cancelling_at*: Option[int64]
    completed_at*: Option[int64]
    error_file_id*: Option[string]
    errors*: Option[BatchErrors]
    expired_at*: Option[int64]
    expires_at*: Option[int64]
    failed_at*: Option[int64]
    finalizing_at*: Option[int64]
    in_progress_at*: Option[int64]
    metadata*: Option[RawJson]
    model*: Option[string]
    output_file_id*: Option[string]
    request_counts*: Option[BatchRequestCounts]
    usage*: Option[BatchUsage]

  BatchList* = object
    `object`*: string
    data*: seq[Batch]
    first_id*: string
    last_id*: string
    has_more*: bool

  OutputExpiresAfter* = object
    anchor*: string
    seconds*: int

  BatchCreateParams* = object
    input_file_id*: string
    endpoint*: string
    completion_window*: string
    metadata*: RawJson
    output_expires_after*: OutputExpiresAfter

  BatchInputLine* = object
    custom_id*: string
    `method`*: string = "POST"
    url*: string
    body*: RawJson

  BatchOutputResponse* = object
    status_code*: int
    request_id*: string
    body*: RawJson

  BatchOutputError* = object
    code*: string
    message*: string

  BatchOutputLine* = object
    id*: string
    custom_id*: string
    response*: Option[BatchOutputResponse]
    error*: Option[BatchOutputError]

template writeJsonField(s: Stream; name: string; value: untyped) =
  if comma: streams.write(s, ",")
  else: comma = true
  escapeJson(s, name)
  streams.write(s, ":")
  writeJson(s, value)

proc writeJson*(s: Stream; x: BatchCreateParams) =
  var comma = false
  streams.write(s, "{")
  writeJsonField(s, "input_file_id", x.input_file_id)
  writeJsonField(s, "endpoint", x.endpoint)
  writeJsonField(s, "completion_window", x.completion_window)
  if string(x.metadata).len > 0:
    writeJsonField(s, "metadata", x.metadata)
  if x.output_expires_after.seconds > 0:
    writeJsonField(s, "output_expires_after", x.output_expires_after)
  streams.write(s, "}")

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

proc readJson*(dst: var BatchStatus; p: var JsonParser) =
  var value: string
  readJson(value, p)
  case value
  of "validating": dst = BatchStatus.validating
  of "failed": dst = BatchStatus.failed
  of "in_progress": dst = BatchStatus.in_progress
  of "finalizing": dst = BatchStatus.finalizing
  of "completed": dst = BatchStatus.completed
  of "expired": dst = BatchStatus.expired
  of "cancelling": dst = BatchStatus.cancelling
  of "cancelled": dst = BatchStatus.cancelled
  else: dst = BatchStatus.unknown

proc readJson*(dst: var BatchRequestCounts; p: var JsonParser) =
  readObjectFields(p):
    case fieldName
    of "total": readJson(dst.total, p)
    of "completed": readJson(dst.completed, p)
    of "failed": readJson(dst.failed, p)
    else: skipJson(p)

proc readJson*(dst: var BatchUsageInputDetails; p: var JsonParser) =
  readObjectFields(p):
    case fieldName
    of "cached_tokens": readJson(dst.cached_tokens, p)
    else: skipJson(p)

proc readJson*(dst: var BatchUsageOutputDetails; p: var JsonParser) =
  readObjectFields(p):
    case fieldName
    of "reasoning_tokens": readJson(dst.reasoning_tokens, p)
    else: skipJson(p)

proc readJson*(dst: var BatchUsage; p: var JsonParser) =
  readObjectFields(p):
    case fieldName
    of "input_tokens": readJson(dst.input_tokens, p)
    of "input_tokens_details": readJson(dst.input_tokens_details, p)
    of "output_tokens": readJson(dst.output_tokens, p)
    of "output_tokens_details": readJson(dst.output_tokens_details, p)
    of "total_tokens": readJson(dst.total_tokens, p)
    else: skipJson(p)

proc readJson*(dst: var BatchError; p: var JsonParser) =
  readObjectFields(p):
    case fieldName
    of "code": readJson(dst.code, p)
    of "line": readJson(dst.line, p)
    of "message": readJson(dst.message, p)
    of "param": readJson(dst.param, p)
    else: skipJson(p)

proc readJson*(dst: var BatchErrors; p: var JsonParser) =
  readObjectFields(p):
    case fieldName
    of "object": readJson(dst.`object`, p)
    of "data": readJson(dst.data, p)
    else: skipJson(p)

proc readJson*(dst: var Batch; p: var JsonParser) =
  readObjectFields(p):
    case fieldName
    of "id": readJson(dst.id, p)
    of "completion_window": readJson(dst.completion_window, p)
    of "created_at": readJson(dst.created_at, p)
    of "endpoint": readJson(dst.endpoint, p)
    of "input_file_id": readJson(dst.input_file_id, p)
    of "object": readJson(dst.`object`, p)
    of "status": readJson(dst.status, p)
    of "cancelled_at": readJson(dst.cancelled_at, p)
    of "cancelling_at": readJson(dst.cancelling_at, p)
    of "completed_at": readJson(dst.completed_at, p)
    of "error_file_id": readJson(dst.error_file_id, p)
    of "errors": readJson(dst.errors, p)
    of "expired_at": readJson(dst.expired_at, p)
    of "expires_at": readJson(dst.expires_at, p)
    of "failed_at": readJson(dst.failed_at, p)
    of "finalizing_at": readJson(dst.finalizing_at, p)
    of "in_progress_at": readJson(dst.in_progress_at, p)
    of "metadata": readJson(dst.metadata, p)
    of "model": readJson(dst.model, p)
    of "output_file_id": readJson(dst.output_file_id, p)
    of "request_counts": readJson(dst.request_counts, p)
    of "usage": readJson(dst.usage, p)
    else: skipJson(p)

proc readJson*(dst: var BatchList; p: var JsonParser) =
  readObjectFields(p):
    case fieldName
    of "object": readJson(dst.`object`, p)
    of "data": readJson(dst.data, p)
    of "first_id": readJson(dst.first_id, p)
    of "last_id": readJson(dst.last_id, p)
    of "has_more": readJson(dst.has_more, p)
    else: skipJson(p)

proc readJson*(dst: var BatchOutputResponse; p: var JsonParser) =
  readObjectFields(p):
    case fieldName
    of "status_code": readJson(dst.status_code, p)
    of "request_id": readJson(dst.request_id, p)
    of "body": readJson(dst.body, p)
    else: skipJson(p)

proc readJson*(dst: var BatchOutputError; p: var JsonParser) =
  readObjectFields(p):
    case fieldName
    of "code": readJson(dst.code, p)
    of "message": readJson(dst.message, p)
    else: skipJson(p)

proc readJson*(dst: var BatchOutputLine; p: var JsonParser) =
  readObjectFields(p):
    case fieldName
    of "id": readJson(dst.id, p)
    of "custom_id": readJson(dst.custom_id, p)
    of "response": readJson(dst.response, p)
    of "error": readJson(dst.error, p)
    else: skipJson(p)
