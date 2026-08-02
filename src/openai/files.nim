import std/strutils
import relay
import jsonx
import ./[core, http]
import ./schema/files_schema

export core
export files_schema

const
  OpenAIFilesUrl* = "https://api.openai.com/v1/files"
  DefaultMultipartBoundary* = "openai-nim-batch"

type
  FileCreateResult* = FileObject

proc listQuery(after, purpose: string; limit: int): string =
  var parts: seq[string] = @[]
  if after.len > 0:
    parts.add("after=" & after)
  if purpose.len > 0:
    parts.add("purpose=" & purpose)
  if limit > 0:
    parts.add("limit=" & $limit)
  if parts.len > 0:
    result = "?" & parts.join("&")

proc fileUploadBody*(filename, purpose, content, boundary: string): string =
  result = "--" & boundary & "\r\n" &
    "Content-Disposition: form-data; name=\"purpose\"\r\n\r\n" &
    purpose & "\r\n" &
    "--" & boundary & "\r\n" &
    "Content-Disposition: form-data; name=\"file\"; filename=\"" & filename & "\"\r\n" &
    "Content-Type: application/json\r\n\r\n" &
    content & "\r\n" &
    "--" & boundary & "--\r\n"

proc fileUploadRequest*(cfg: OpenAIConfig; filename, purpose: string;
    content: sink string; boundary = DefaultMultipartBoundary; url = "";
    requestId = 0'i64; timeoutMs = 0;
    headers: sink HttpHeaders = emptyHttpHeaders()): RequestSpec =
  let target = if url.len > 0: url else: OpenAIFilesUrl
  var hs = cfg.withAuthHeader(headers)
  hs["Content-Type"] = "multipart/form-data; boundary=" & boundary
  RequestSpec(
    verb: hvPost,
    url: target,
    headers: hs,
    body: fileUploadBody(filename, purpose, content, boundary),
    requestId: requestId,
    timeoutMs: timeoutMs
  )

proc fileUploadAdd*(batch: var RequestBatch; cfg: OpenAIConfig;
    filename, purpose: string; content: sink string;
    boundary = DefaultMultipartBoundary; url = "";
    requestId = 0'i64; timeoutMs = 0;
    headers: sink HttpHeaders = emptyHttpHeaders()) =
  let target = if url.len > 0: url else: OpenAIFilesUrl
  var hs = cfg.withAuthHeader(headers)
  hs["Content-Type"] = "multipart/form-data; boundary=" & boundary
  batch.addRequest(
    verb = hvPost,
    url = target,
    headers = hs,
    body = fileUploadBody(filename, purpose, content, boundary),
    requestId = requestId,
    timeoutMs = timeoutMs
  )

proc fileRetrieveRequest*(cfg: OpenAIConfig; fileId: string; url = "";
    requestId = 0'i64; timeoutMs = 0;
    headers: sink HttpHeaders = emptyHttpHeaders()): RequestSpec =
  let target = if url.len > 0: url else: OpenAIFilesUrl & "/" & fileId
  plainRequest(cfg, hvGet, target, requestId, timeoutMs, headers)

proc fileListRequest*(cfg: OpenAIConfig; after = ""; purpose = ""; limit = 0;
    url = ""; requestId = 0'i64; timeoutMs = 0;
    headers: sink HttpHeaders = emptyHttpHeaders()): RequestSpec =
  let target = if url.len > 0: url else:
    OpenAIFilesUrl & listQuery(after, purpose, limit)
  plainRequest(cfg, hvGet, target, requestId, timeoutMs, headers)

proc fileContentRequest*(cfg: OpenAIConfig; fileId: string; url = "";
    requestId = 0'i64; timeoutMs = 0;
    headers: sink HttpHeaders = emptyHttpHeaders()): RequestSpec =
  let target = if url.len > 0: url else: OpenAIFilesUrl & "/" & fileId & "/content"
  plainRequest(cfg, hvGet, target, requestId, timeoutMs, headers)

proc fileDeleteRequest*(cfg: OpenAIConfig; fileId: string; url = "";
    requestId = 0'i64; timeoutMs = 0;
    headers: sink HttpHeaders = emptyHttpHeaders()): RequestSpec =
  let target = if url.len > 0: url else: OpenAIFilesUrl & "/" & fileId
  plainRequest(cfg, hvDelete, target, requestId, timeoutMs, headers)

proc fileParse*(body: string; dst: var FileObject): bool =
  try:
    dst = fromJson(body, FileObject)
    result = true
  except CatchableError:
    result = false

proc fileListParse*(body: string; dst: var FileList): bool =
  try:
    dst = fromJson(body, FileList)
    result = true
  except CatchableError:
    result = false

proc fileDeletedParse*(body: string; dst: var FileDeleted): bool =
  try:
    dst = fromJson(body, FileDeleted)
    result = true
  except CatchableError:
    result = false

proc idOf*(x: FileObject): lent string {.inline.} =
  result = x.id

proc idOf*(x: var FileObject): var string {.inline.} =
  result = x.id
