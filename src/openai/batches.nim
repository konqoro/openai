import std/[options, strutils]

import jsonx
import relay

import ./[core, http]

export core

type
  BatchStatus* {.pure.} = enum
    validating
    failed
    in_progress
    finalizing
    completed
    expired
    cancelling
    cancelled

  BatchCounts* = object
    total*: int
    completed*: int
    failed*: int

  BatchInputUsage* = object
    cached_tokens*: int

  BatchOutputUsage* = object
    reasoning_tokens*: int

  BatchUsage* = object
    input_tokens*: int
    input_tokens_details*: BatchInputUsage
    output_tokens*: int
    output_tokens_details*: BatchOutputUsage
    total_tokens*: int

  Batch* = object
    id*: string
    `object`*: string
    endpoint*: string
    errors*: Option[RawJson]
    input_file_id*: string
    completion_window*: string
    status*: BatchStatus
    output_file_id*: Option[string]
    error_file_id*: Option[string]
    created_at*: int64
    in_progress_at*: Option[int64]
    expires_at*: Option[int64]
    finalizing_at*: Option[int64]
    completed_at*: Option[int64]
    failed_at*: Option[int64]
    expired_at*: Option[int64]
    cancelling_at*: Option[int64]
    cancelled_at*: Option[int64]
    request_counts*: BatchCounts
    metadata*: Option[RawJson]
    model*: Option[string]
    usage*: Option[BatchUsage]

  BatchList* = object
    `object`*: string
    data*: seq[Batch]
    first_id*: Option[string]
    last_id*: Option[string]
    has_more*: bool

  File* = object
    id*: string
    `object`*: string
    bytes*: int
    created_at*: int64
    expires_at*: Option[int64]
    filename*: string
    purpose*: string
    status*: Option[string]
    status_details*: Option[RawJson]

  BatchCreate = object
    input_file_id: string
    endpoint: string
    completion_window: string
    metadata: RawJson

proc uploadRequest*(cfg: OpenAIConfig; data: string; requestId = 0'i64;
                    timeoutMs = 0): RequestSpec =
  var boundary = "scamdial-batch-boundary"
  while data.contains(boundary):
    boundary.add '-'
  let body =
    "--" & boundary & "\r\n" &
    "Content-Disposition: form-data; name=\"purpose\"\r\n\r\n" &
    "batch\r\n" &
    "--" & boundary & "\r\n" &
    "Content-Disposition: form-data; name=\"file\"; filename=\"batch.jsonl\"\r\n" &
    "Content-Type: application/jsonl\r\n\r\n" &
    data & "\r\n" &
    "--" & boundary & "--\r\n"
  var headers = cfg.withDefaultHeaders()
  headers["Content-Type"] = "multipart/form-data; boundary=" & boundary
  RequestSpec(
    verb: hvPost,
    url: cfg.baseUrl & "/files",
    headers: headers,
    body: body,
    requestId: requestId,
    timeoutMs: timeoutMs,
  )

proc createRequest*(cfg: OpenAIConfig; fileId: string;
                    metadata = RawJson("{}"); requestId = 0'i64;
                    timeoutMs = 0): RequestSpec =
  jsonPostRequest(
    OpenAIConfig(
      baseUrl: cfg.baseUrl,
      url: cfg.baseUrl & "/batches",
      apiKey: cfg.apiKey,
    ),
    BatchCreate(
      input_file_id: fileId,
      endpoint: "/v1/chat/completions",
      completion_window: "24h",
      metadata: metadata,
    ),
    requestId,
    timeoutMs,
  )

proc getRequest*(cfg: OpenAIConfig; id: string; requestId = 0'i64;
                 timeoutMs = 0): RequestSpec =
  RequestSpec(
    verb: hvGet,
    url: cfg.baseUrl & "/batches/" & id,
    headers: cfg.withDefaultHeaders(),
    requestId: requestId,
    timeoutMs: timeoutMs,
  )

proc listRequest*(cfg: OpenAIConfig; after = ""; limit = 100;
                  requestId = 0'i64; timeoutMs = 0): RequestSpec =
  var url = cfg.baseUrl & "/batches?limit=" & $limit
  if after.len > 0:
    url.add "&after=" & after
  RequestSpec(
    verb: hvGet,
    url: url,
    headers: cfg.withDefaultHeaders(),
    requestId: requestId,
    timeoutMs: timeoutMs,
  )

proc cancelRequest*(cfg: OpenAIConfig; id: string; requestId = 0'i64;
                    timeoutMs = 0): RequestSpec =
  RequestSpec(
    verb: hvPost,
    url: cfg.baseUrl & "/batches/" & id & "/cancel",
    headers: cfg.withDefaultHeaders(),
    requestId: requestId,
    timeoutMs: timeoutMs,
  )

proc contentRequest*(cfg: OpenAIConfig; id: string; requestId = 0'i64;
                     timeoutMs = 0): RequestSpec =
  RequestSpec(
    verb: hvGet,
    url: cfg.baseUrl & "/files/" & id & "/content",
    headers: cfg.withDefaultHeaders(),
    requestId: requestId,
    timeoutMs: timeoutMs,
  )

proc parseBatch*(body: string): Batch =
  fromJson(body, Batch)

proc parseBatches*(body: string): BatchList =
  fromJson(body, BatchList)

proc parseFile*(body: string): File =
  fromJson(body, File)
