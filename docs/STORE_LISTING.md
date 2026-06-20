# Google Play Store Listing — Dyslexic Reader

Copy-and-paste reference for the Play Console store listing and the "App content"
declarations. Field values are meant to be used verbatim; character counts are
given because Play enforces hard limits.

- **App name / package:** Dyslexic Reader — `com.dobosp.dyslexic_reader`
- **Version:** 1.0.0 (versionName `1.0.0`, versionCode `1`; `version: 1.0.0+1` in `pubspec.yaml`)
- **Price:** Free. No ads, no in-app purchases, no subscriptions, no accounts.
- **Privacy & data:** Fully on-device. No analytics, no tracking, no servers.
- See `docs/PUBLISHING.md` for the end-to-end "how to publish" guide.

> **Honesty rule (applies to every text field below):** Dyslexic Reader is a
> *reading aid*. Do **not** claim it treats, cures, diagnoses, or "fixes"
> dyslexia. Lead with the evidence-backed features (spacing, read-aloud with
> highlighting, reading ruler — see `docs/RESEARCH.md`); present fonts and
> bionic reading only as optional personalization.

---

## 1. App title (max 30 characters)

```
Dyslexic Reader
```

**15 / 30 characters.** Keep it exactly equal to `kAppName` in
`lib/app/app_info.dart`.

---

## 2. Short description (max 80 characters)

```
Reflow PDFs, Word & text for easier reading: spacing, read-aloud, ruler.
```

**72 / 80 characters.**

---

## 3. Full description (max 4000 characters)

```
Dyslexic Reader makes documents easier to read. Open a PDF, Word document, or
plain text and the app re-renders it in a calm, comfortable reading surface that
you control — then reads it aloud, highlighting each word as it goes.

It is built on the evidence about what actually helps people who find reading
hard. The features with the strongest research support come first; the famous-
but-unproven ones are offered only as optional extras, never as a cure.

WHAT IT DOES
• Reflows PDFs, Word (.docx), and text into a clean, adjustable layout
• Adjustable letter, word, line, and paragraph spacing
• Legible fonts: Atkinson Hyperlegible, Lexend, OpenDyslexic, or your system font
• Gentle, low-glare themes (cream, sepia, off-white, dark, high-contrast) —
  never harsh pure white
• Reading focus that follows your reading — highlight the line you’re on (the
  default) or switch to a tinted or dimmed focus band (five modes in total)
• Read aloud with the words highlighted as they are spoken, adjustable speed,
  pitch, and your choice of voice
• On-device text recognition (OCR) for scanned PDFs
• Search within a document
• Bookmarks and notes anchored on the text (highlighted, with a margin marker),
  plus a document outline
• Page view or continuous scrolling

PRIVATE BY DESIGN
Everything happens on your device. There are no accounts, no ads, and no
tracking, and your documents never leave your phone. The app works offline. It
only uses the internet once, to download the text-recognition model the first
time you open a scanned PDF — and even then it never uploads your documents.

FREE
Dyslexic Reader is completely free, with no ads and no in-app purchases.

A NOTE ON THE EVIDENCE
Generous spacing, text-to-speech with synchronized highlighting, and reading
rulers have strong research support for dyslexic readers. Special fonts and
"bionic" reading have weak or mixed evidence, so they are included as options you
can try — not as promises. Dyslexic Reader is a reading aid; it does not treat,
cure, or diagnose dyslexia.

Made with care for anyone who finds reading tiring — people with dyslexia, low
vision, or anyone who simply prefers to read their own way.
```

(Comfortably under 4000 characters.)

---

## 4. Release notes — "What's new" for v1.0.0

```
First release of Dyslexic Reader.

• Open PDFs, Word docs and text and read them your way
• Adjustable spacing, legible fonts, gentle themes
• Reading focus that follows your reading, and read-aloud with word highlighting
• On-device OCR for scanned PDFs, in-document search, bookmarks and notes

Free, no ads, and fully on-device.
```

This must match `distribution/whatsnew/whatsnew-en-US` (used by CD). Keep each
locale file ≤ 500 characters.

---

## 5. Category, tags, contact

- **Category:** **Education** (recommended — the app is an assistive/learning
  tool used to read and study documents, which fits Education better than the
  passive consumption framing of *Books & Reference*; **Books & Reference** is a
  reasonable fallback if you prefer).
- **Tags:** choose from Play's list — e.g. *Education*, *Accessibility*,
  *Productivity*. Keywords to weave into the description (not a separate field):
  dyslexia, reading, text to speech, read aloud, PDF reader, reading ruler,
  OpenDyslexic, accessibility, document reader.
- **Contact email:** pauldobos6@gmail.com *(swap for a dedicated support address
  if you prefer not to use a personal email)*.
- **Privacy policy URL:** host `docs/PRIVACY_POLICY.md` publicly and paste the
  URL here (see `docs/PUBLISHING.md` §4). Placeholder until hosted:
  `https://github.com/pauldobos6/dyslexic-reader/blob/main/docs/PRIVACY_POLICY.md`

---

## 6. Content rating (IARC questionnaire)

Expected result: **Everyone**. Answer honestly:

- Violence, sexual content, profanity, controlled substances, gambling: **No**.
- **User-generated content / user can import arbitrary content:** **Yes** — the
  app opens documents the user provides. Note there is no sharing or online
  community; content stays on the device. (Answer this accurately so the rating
  is valid.)
- Data collection: none (see Data Safety below).

---

## 7. Data Safety form

Declare **no data collected and no data shared**. The app processes documents
on-device only.

| Play data category | Collected? | Shared? | Notes |
|---|---|---|---|
| Name, email, user IDs, address, phone | No | No | No accounts, no sign-in |
| Location | No | No | — |
| Financial info | No | No | Free; no purchases |
| Health & fitness | No | No | — |
| Messages | No | No | — |
| Photos & videos | No | No | — |
| Audio files | No | No | TTS is system-side; no recording |
| Files & docs | No | No | Documents are read **on-device only**, never uploaded |
| Calendar, contacts | No | No | — |
| App activity / interactions | No | No | No analytics |
| Web browsing | No | No | — |
| App info & performance (crash logs, diagnostics) | No | No | No crash/analytics SDK |
| Device or other IDs | No | No | — |

Additional Data Safety answers:

- **Is all user data encrypted in transit?** Not applicable — no user data is
  transmitted.
- **Can users request data deletion?** Data is local; uninstalling the app
  deletes everything.
- **Committed to Play Families Policy?** Target audience is teens and adults
  (not designed for children), so the Families program does not apply.

**INTERNET permission explanation (for review notes):** the app declares
`INTERNET` solely to (1) download the ~20 MB on-device OCR model the first time a
scanned PDF is imported, and (2) allow the device's own text-to-speech engine to
fetch/stream voices if it needs to. No user documents or personal data are sent.

---

## 8. Graphic assets

Already generated (regenerate with `python3 tool/generate_icons.py`):

| Asset | File | Spec |
|---|---|---|
| App icon (store) | `docs/store/play_icon_512.png` | 512×512, 32-bit PNG, no alpha |
| Feature graphic | `docs/store/feature_graphic_1024x500.png` | 1024×500, no alpha |
| Launcher icon | `android/app/src/main/res/mipmap-*` | adaptive + legacy, all densities |

**Still required: phone screenshots** (Play needs **at least 2**, up to 8;
recommended **1080×1920**). Capture on a device/emulator — suggested screens:
the library, the reader with generous spacing, the theme picker, the reading
ruler, read-aloud with highlighting, and the settings screen. See
`docs/PUBLISHING.md` §5 for the `adb` capture command.
