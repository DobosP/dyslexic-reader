# Status — dyslexic-reader

Last verified: 2026-07-02

Single source of current truth for this repo. On any doc conflict:
this file > newest-dated ADR in `docs/adr/` > everything else.

## Current state

- **v1.0 launch candidate — feature-complete.** `README.md` §Status is the
  verified feature-status truth (OCR, .docx import, read-aloud with word sync,
  reading ruler, outline, onboarding, TalkBack pass all shipped in code).
- Remaining work before release is **process, not code**, gated by
  [`docs/PUBLISHING.md`](docs/PUBLISHING.md): Play account, hosted
  privacy-policy URL, screenshots, closed test.
- Post-1.0 backlog: [`docs/ROADMAP.md`](docs/ROADMAP.md) (unchecked items —
  lang-ID, RTL, iOS, localization, AI summaries are genuinely not in v1.0).
- Decisions: [`docs/adr/`](docs/adr/) (ADR-0001: PDF parsing = PdfBox-Android
  subclassed stripper).

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
