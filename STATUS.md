# Status — dyslexic-reader

Durable status for agents. Update this file when project direction, verification commands, or operational assumptions change.

## Role in the fleet
Standalone Flutter reader app with local user-library persistence.

## Current operational focus
- Preserve user library data across torn/corrupt index writes.
- Keep index-store recovery behavior tested.
- Treat signing configs, keystores, and env files as secret-sensitive.

## Standard verification
```bash
export PATH="$HOME/flutter/bin:$PATH"
flutter test test/library_index_store_test.dart
git diff --check
```

## Agent notes
- Do not claim full app validation from one targeted persistence test.
- Never read or print secret values.
