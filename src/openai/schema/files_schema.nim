import std/options
export options

type
  FilePurpose* = enum
    assistants, assistants_output, batch, batch_output,
    fine_tune = "fine-tune", fine_tune_results = "fine-tune-results",
    vision, user_data

  FileInfo* = object
    id*: string
    bytes*: int
    created_at*: int64
    filename*: string
    `object`*: string
    purpose*: FilePurpose
    expires_at*: Option[int64]

  DeletedFile* = object
    id*: string
    deleted*: bool
    `object`*: string

  FilePage* = object
    `object`*: string
    data*: seq[FileInfo]
    first_id*: string
    last_id*: string
    has_more*: bool
