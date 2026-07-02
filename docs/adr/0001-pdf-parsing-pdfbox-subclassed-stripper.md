# ADR-0001: PDF parsing = PdfBox-Android with a subclassed PDFTextStripper

Date: 2026-05-29
Status: accepted

## Decision
Stay on-device with PdfBox-Android (Apache-2.0) and reconstruct document
structure (h1/h2/h3/p blocks, paragraph breaks, running header/footer removal,
de-hyphenation) in a `PDFTextStripper` subclass (`StructuredTextStripper.kt`)
from per-glyph geometry + font size. Do not switch PDF engines.

## Context / why
Plain `getText()` throws away the geometry PdfBox already computes; a stripper
subclass keeps it and rebuilds structure (same approach as Immersive Reader /
Liquid Mode). Why not the alternatives:
- **MuPDF** — best built-in structure, but AGPL: incompatible with a
  closed-source app.
- **Pdfium/pdfrx** — extracts in storage order, not reading order; no win over
  PdfBox.
- **Cloud layout services** (Azure Document Intelligence, Textract, Document
  AI) — paid and off-device; at most a future opt-in "Enhanced parsing" tier.
- **ML pipelines** (Docling, Marker, Surya) — not phone-feasible.

Detail record (heuristics, engine comparison table, sources):
[`docs/PDF_PARSING.md`](../PDF_PARSING.md).

## Consequences
- License-clean (Apache-2.0) and fully on-device; structure quality rests on
  our heuristics rather than an engine's built-in analysis.
- Scanned PDFs (`hasText == false`) route to on-device ML Kit OCR (shipped
  4fb9650), then the same line-to-block heuristics.
- Revisit only for multi-column or tagged-PDF fast-path needs — options are
  pre-scoped in PDF_PARSING.md "Future options".
