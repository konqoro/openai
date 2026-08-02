import relay
import jsonx
import ./core

proc withAuthHeader*(cfg: OpenAIConfig;
    headers: sink HttpHeaders = emptyHttpHeaders()): HttpHeaders =
  result = headers
  result["Authorization"] = "Bearer " & cfg.apiKey

proc withDefaultHeaders*(cfg: OpenAIConfig;
    headers: sink HttpHeaders = emptyHttpHeaders()): HttpHeaders =
  result = cfg.withAuthHeader(headers)
  result["Content-Type"] = "application/json"

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

proc jsonPostRequest*[T](cfg: OpenAIConfig; params: T;
    requestId = 0'i64; timeoutMs = 0;
    headers: sink HttpHeaders = emptyHttpHeaders()): RequestSpec =
  RequestSpec(
    verb: hvPost,
    url: cfg.url,
    headers: cfg.withDefaultHeaders(headers),
    body: toJson(params),
    requestId: requestId,
    timeoutMs: timeoutMs
  )

proc jsonPostAdd*[T](batch: var RequestBatch; cfg: OpenAIConfig; params: T;
    requestId = 0'i64; timeoutMs = 0;
    headers: sink HttpHeaders = emptyHttpHeaders()) =
  batch.addRequest(
    verb = hvPost,
    url = cfg.url,
    headers = cfg.withDefaultHeaders(headers),
    body = toJson(params),
    requestId = requestId,
    timeoutMs = timeoutMs
  )
