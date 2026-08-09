import std/options
export options
import jsonx
import jsonx/streams

type
  BatchStatus* = enum
    validating, failed, in_progress, finalizing, completed, expired,
    cancelling, cancelled

  BatchCounts* = object
    total*: int
    completed*: int
    failed*: int

  BatchInputTokenDetails* = object
    cached_tokens*: int

  BatchOutputTokenDetails* = object
    reasoning_tokens*: int

  BatchUsage* = object
    input_tokens*: int
    input_tokens_details*: BatchInputTokenDetails
    output_tokens*: int
    output_tokens_details*: BatchOutputTokenDetails
    total_tokens*: int

  BatchError* = object
    code*: string
    line*: Option[int]
    message*: string
    param*: Option[string]

  BatchErrorList* = object
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
    errors*: Option[BatchErrorList]
    expired_at*: Option[int64]
    expires_at*: Option[int64]
    failed_at*: Option[int64]
    finalizing_at*: Option[int64]
    in_progress_at*: Option[int64]
    metadata*: Option[RawJson]
    model*: Option[string]
    output_file_id*: Option[string]
    request_counts*: Option[BatchCounts]
    usage*: Option[BatchUsage]

  BatchList* = object
    `object`*: string
    data*: seq[Batch]
    first_id*: string
    last_id*: string
    has_more*: bool

  BatchOutputExpiry* = object
    anchor*: string
    seconds*: int

  BatchParams* = object
    input_file_id*: string
    endpoint*: string
    completion_window*: string
    metadata*: RawJson
    output_expires_after*: BatchOutputExpiry

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

proc writeJson*(s: Stream; x: BatchParams) =
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
