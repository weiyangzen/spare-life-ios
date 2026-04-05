# spare-life-ios-app

This workspace is reserved for the iOS client.

## Structure

- `App/`: app entry, scene lifecycle, and bootstrap wiring.
- `Features/CompanionChat/`: emotional companion chat UI and feature logic.
- `Features/Shared/`: shared UI components and feature helpers.
- `Domain/Models/`: core chat, memory, persona, and message entities.
- `Domain/UseCases/`: application use cases and business flows.
- `LocalBackend/`: lightweight embedded backend for offline-first dialogue.
- `Services/EmotionEngine/`: emotional state and companion behavior services.
- `Services/LLMBridge/`: model adapter boundary if local or remote inference is added later.
- `Resources/`: assets, strings, prompts, and bundled seeds.
- `Tests/`: app-level tests.
