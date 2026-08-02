import std/options
export options
import jsonx
import jsonx/streams
import ../timestamp

export timestamp

{.define: jsonxLenient.}

type
  BatchStatus* = enum
    validating, failed, in_progress, finalizing, completed, expired,
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
    input_tokens_details*: Option[BatchUsageInputDetails]
    output_tokens*: int
    output_tokens_details*: Option[BatchUsageOutputDetails]
    total_tokens*: int

  BatchError* = object
    code*: string
    line*: Option[int]
    message*: string
    param*: string

  BatchErrors* = object
    `object`*: string
    data*: seq[BatchError]

  Batch* = object
    id*: string
    completion_window*: string
    created_at*: Timestamp
    endpoint*: string
    input_file_id*: string
    `object`*: string
    status*: BatchStatus
    cancelled_at*: Option[Timestamp]
    cancelling_at*: Option[Timestamp]
    completed_at*: Option[Timestamp]
    error_file_id*: string
    errors*: Option[BatchErrors]
    expired_at*: Option[Timestamp]
    expires_at*: Option[Timestamp]
    failed_at*: Option[Timestamp]
    finalizing_at*: Option[Timestamp]
    in_progress_at*: Option[Timestamp]
    metadata*: RawJson
    model*: string
    output_file_id*: string
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
    `method`*: string
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
  if x.output_expires_after.anchor.len > 0:
    writeJsonField(s, "output_expires_after", x.output_expires_after)
  streams.write(s, "}")
