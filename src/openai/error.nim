## Forward-compatible parsing for OpenAI API error envelopes.

import std/options
export options
import jsonx
import jsonx/parsejson

type
  ApiError* = object
    message*: string
    `type`*: string
    param*: Option[string]
    code*: Option[string]

  ErrorResponse* = object
    error*: ApiError

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

proc readJson*(dst: var ErrorResponse; p: var JsonParser;
    unknownFields: UnknownFieldPolicy) =
  var foundError = false
  readObjectFields(p):
    case fieldName
    of "error":
      foundError = true
      readJson(dst.error, p, unknownFields)
    else:
      if unknownFields == ufSkip:
        skipJson(p)
      else:
        raiseParseErr(p, "valid object field")
  if not foundError:
    raiseParseErr(p, "error field")

proc errorParse*(body: string; dst: var ErrorResponse): bool =
  ## Parses a forward-compatible error envelope.
  try:
    dst = fromJson(body, ErrorResponse)
    result = true
  except CatchableError:
    result = false

proc errorOf*(x: ErrorResponse): lent ApiError =
  ## Returns the parsed API error.
  result = x.error
