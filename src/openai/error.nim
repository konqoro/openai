## Forward-compatible parsing for OpenAI API error envelopes.

import std/options
export options
import jsonx
import jsonx/parsejson

type
  OpenAIError* = object
    message*: string
    `type`*: string
    param*: Option[string]
    code*: Option[string]

  OpenAIErrorResponse* = object
    error*: OpenAIError

proc readJson*(dst: var OpenAIErrorResponse; p: var JsonParser;
    unknownFields: UnknownFieldPolicy) =
  var foundError = false
  eat(p, tkCurlyLe)
  while p.tok != tkCurlyRi:
    if p.tok != tkString:
      raiseParseErr(p, "string literal as key")
    let fieldName = p.a
    discard getTok(p)
    eat(p, tkColon)
    case fieldName
    of "error":
      foundError = true
      readJson(dst.error, p, unknownFields)
    else:
      if unknownFields == ufSkip:
        skipJson(p)
      else:
        raiseParseErr(p, "valid object field")
    if p.tok == tkComma:
      discard getTok(p)
    elif p.tok != tkCurlyRi:
      raiseParseErr(p, "comma or closing brace")
  eat(p, tkCurlyRi)
  if not foundError:
    raiseParseErr(p, "error field")

proc errorParse*(body: string; dst: var OpenAIErrorResponse): bool =
  ## Parses a forward-compatible error envelope.
  try:
    dst = fromJson(body, OpenAIErrorResponse)
    result = true
  except CatchableError:
    result = false

proc errorOf*(x: OpenAIErrorResponse): lent OpenAIError =
  ## Returns the parsed API error.
  result = x.error
