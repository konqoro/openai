# Repository Guidelines

## Project Structure & Modules
- `src/openai.nim`: package entry; `import openai` re-exports the capability
  modules. Use `import openai/<module>` for a scoped subset.
- `src/openai/`: Capability-first public modules and shared internals.
  - `chat.nim`: chat-completions API helpers and response accessors.
  - `embeddings.nim`: embeddings request helpers and response accessors.
  - `audio_speech.nim`: text-to-speech request helpers.
  - `batch.nim`: Batches API helpers, JSONL line builders, and output/error
    line parsing.
  - `files.nim`: Files API helpers including multipart upload.
  - `core.nim`: shared config (`OpenAIConfig` with base URL, key, org, project).
  - `http.nim`: shared header/request builders over relay, query-string helper.
  - `schema/`: direct JSON-mapped schema types grouped by capability.
- Retry policy and HTTP status classification live in `relay` (`relay/retry`,
  `relay/http_status`); they are transport-generic and not part of this package.
- `tests/`: Executable test programs and local `tests/config.nims`.
- `examples/`: Runnable examples and local `examples/config.nims`.
- Root files:
  - `openai.nimble`: package metadata and test task.
  - `config.nims`: project-local source path setup.
  - `nim.cfg`: Atlas-managed dependency paths. Do not hand-edit.

## Build, Test, and Development
- Dependency workflow: use Atlas workspace/deps setup.
- Do not add Nimble-based dependency install steps to docs/automation for this repo.
- Use `nim` compile/run commands directly.
- Run tests from the project root:
  - `nim c -r tests/tester.nim` (auto-discovers every `t*.nim` file)
  - `nim c -d:release -r tests/tester.nim`
  - `nim c -d:danger -r tests/tester.nim`
- Build examples:
  - `nim c examples/live_ocr_retry.nim`
  - `nim c examples/live_batch_chat_polling.nim`

## Coding Style & Naming
- Indentation: 2 spaces, no tabs.
- Nim naming:
  - Types/enums: `PascalCase`
  - Procs/vars/fields: `camelCase`
  - Modules/files: lowercase with underscores where helpful.
- Keep control flow explicit; avoid hidden transport abstractions over Relay.

## Testing Guidelines
- This project does **not** use `unittest`.
- Tests are standalone `t*.nim` programs using `block` scopes and `doAssert`.
- Add tests under `tests/` with `t<topic>.nim` naming; the tester picks them up.
- Keep tests deterministic and bounded.

## Commit & Pull Requests
- Commit messages: short, imperative.
- PRs should include:
  - behavior/API change summary
  - compatibility notes for public API renames
  - test coverage notes (which test files changed)
- Ensure test commands above compile and run successfully before merge.
