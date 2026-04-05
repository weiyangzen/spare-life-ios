# LocalBackend

This module is intended to act as an embedded backend inside the iOS app.

## SQLite Focus

- `SQLite/`: SQLite access layer, connection management, and query helpers.
- `Migrations/`: schema setup and migration scripts or bundled migration definitions.
- `Repositories/`: persistence-facing repositories for messages, sessions, and memories.
- `ConversationMemory/`: memory summarization, recall, and context assembly for companion chat.
