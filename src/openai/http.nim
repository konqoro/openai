import relay
import jsonx
import ./core

proc withAuthHeader*(cfg: OpenAIConfig;
    headers: sink HttpHeaders = emptyHttpHeaders()): HttpHeaders =
  result = headers
  result["Authorization"] = "Bearer " & cfg.apiKey
  if cfg.organization.len > 0:
    result["OpenAI-Organization"] = cfg.organization
  if cfg.project.len > 0:
    result["OpenAI-Project"] = cfg.project

proc withDefaultHeaders*(cfg: OpenAIConfig;
    headers: sink HttpHeaders = emptyHttpHeaders()): HttpHeaders =
  result = cfg.withAuthHeader(headers)
  result["Content-Type"] = "application/json"

proc queryString*(params: QueryParams): string =
  ## Serializes `params` as a URL query string including the leading `?`,
  ## or "" when the query is empty.
  if params.len > 0:
    result = "?" & $params
  else:
    result = ""

proc jsonRequest*[T](cfg: OpenAIConfig; verb: HttpVerb; url: string;
    params: T; requestId = 0'i64; timeoutMs = 0;
    headers: sink HttpHeaders = emptyHttpHeaders()): RequestSpec =
  RequestSpec(
    verb: verb,
    url: url,
    headers: cfg.withDefaultHeaders(headers),
    body: toJson(params),
    requestId: requestId,
    timeoutMs: timeoutMs
  )

proc jsonAdd*[T](batch: var RequestBatch; cfg: OpenAIConfig;
    verb: HttpVerb; url: string; params: T;
    requestId = 0'i64; timeoutMs = 0;
    headers: sink HttpHeaders = emptyHttpHeaders()) =
  batch.addRequest(
    verb = verb,
    url = url,
    headers = cfg.withDefaultHeaders(headers),
    body = toJson(params),
    requestId = requestId,
    timeoutMs = timeoutMs
  )

proc plainRequest*(cfg: OpenAIConfig; verb: HttpVerb; url: string;
    requestId = 0'i64; timeoutMs = 0;
    headers: sink HttpHeaders = emptyHttpHeaders()): RequestSpec =
  RequestSpec(
    verb: verb,
    url: url,
    headers: cfg.withDefaultHeaders(headers),
    body: "",
    requestId: requestId,
    timeoutMs: timeoutMs
  )

proc plainAdd*(batch: var RequestBatch; cfg: OpenAIConfig;
    verb: HttpVerb; url: string;
    requestId = 0'i64; timeoutMs = 0;
    headers: sink HttpHeaders = emptyHttpHeaders()) =
  batch.addRequest(
    verb = verb,
    url = url,
    headers = cfg.withDefaultHeaders(headers),
    body = "",
    requestId = requestId,
    timeoutMs = timeoutMs
  )

proc jsonPostRequest*[T](cfg: OpenAIConfig; url: string; params: T;
    requestId = 0'i64; timeoutMs = 0;
    headers: sink HttpHeaders = emptyHttpHeaders()): RequestSpec =
  jsonRequest(cfg, hvPost, url, params, requestId, timeoutMs, headers)

proc jsonPostAdd*[T](batch: var RequestBatch; cfg: OpenAIConfig; url: string;
    params: T; requestId = 0'i64; timeoutMs = 0;
    headers: sink HttpHeaders = emptyHttpHeaders()) =
  jsonAdd(batch, cfg, hvPost, url, params, requestId, timeoutMs, headers)
