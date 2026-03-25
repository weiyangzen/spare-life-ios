# spare-life-openclaw-plugin

This workspace is reserved for the OpenClaw channel plugin layer.

## Structure

- `manifests/`: channel metadata and plugin descriptors.
- `src/inbound/`: normalize incoming channel payloads.
- `src/outbound/`: build outgoing channel responses.
- `src/adapters/`: platform-specific adapters.
- `src/schemas/`: shared payload schemas and validation contracts.
- `src/handlers/`: orchestration for request and response flow.
- `fixtures/`: sample payloads for local testing.
- `tests/`: plugin-focused tests.
