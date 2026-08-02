import std/options
export options
import ../timestamp

export timestamp

{.define: jsonxLenient.}

type
  FilePurpose* = enum
    assistants, assistants_output, batch, batch_output,
    fine_tune = "fine-tune", fine_tune_results = "fine-tune-results",
    vision, user_data

  FileObject* = object
    id*: string
    bytes*: int
    created_at*: Timestamp
    filename*: string
    `object`*: string
    purpose*: FilePurpose
    expires_at*: Option[Timestamp]

  FileDeleted* = object
    id*: string
    deleted*: bool
    `object`*: string

  FileList* = object
    `object`*: string
    data*: seq[FileObject]
    first_id*: string
    last_id*: string
    has_more*: bool
