# PDF text extraction & structure — approach and options

How the app turns a PDF into well-organized, reflowable text (paragraphs,
headings, reading order), and the parser options we evaluated. Researched 2026.

## Decision

**Stay on-device with PdfBox-Android (Apache-2.0) and reconstruct structure from
per-glyph geometry + font size**, rather than switching PDF engines. Plain
`getText()` throws away the geometry PdfBox already computes; a `PDFTextStripper`
subclass keeps it and rebuilds structure. This is exactly how Microsoft Immersive
Reader and Adobe Liquid Mode work (coordinate + font heuristics; Adobe adds ML for
hard cases).

## What we implemented

`android/app/src/main/kotlin/.../StructuredTextStripper.kt` (a `PDFTextStripper`
subclass) emits **typed blocks** — `h1` / `h2` / `h3` / `p` — instead of flat text:

- **Per-line model** from `TextPosition` geometry: text, top‑y, left/right x,
  dominant font size (mode), bold fraction (font name + `FontDescriptor.fontWeight`).
- **Body baseline** = character‑weighted modal font size.
- **Headings**: line font size ≥ 1.8× / 1.4× / 1.2× body → h1 / h2 / h3; also a
  short, bold, body‑size line → h3.
- **Paragraph breaks**: vertical gap > 1.6× median line advance, or a first‑line
  indent (> ~2× space width); paragraphs flow across page breaks.
- **Running headers/footers / page numbers**: dropped when a normalized line
  repeats near the top/bottom of ≥3 pages.
- **De‑hyphenation**: line‑end `-` joining two letters is merged.

The Dart side (`TextBlock` → `Tokenizer.fromBlocks` → `Paragraph.role`) renders
headings with larger/bold styles and extra spacing (`styleForRole` in
`paginated_reader.dart`). Blocks are cached per document so reopening is instant.

## Engine comparison (for books)

| Engine | Structure quality | License | Verdict |
|---|---|---|---|
| **PdfBox-Android (subclassed)** | Good (our heuristics) | **Apache-2.0** ✅ | **Chosen** — on-device, license-clean, already integrated. |
| MuPDF (stext blocks/lines/spans) | **Best** built-in | **AGPL** / commercial ⚠️ | Avoided — AGPL is incompatible with a closed-source app. |
| Pdfium / pdfrx (`FPDFText`) | Weakest (storage order, not reading order) | BSD / MIT | No win over PdfBox; skip. |
| Cloud: Azure Document Intelligence "Layout", AWS Textract, Google Document AI | **Excellent** (roles, reading order, tables, Markdown) | Paid (~$0.0015–0.065/page), off-device | Optional future "Enhanced parsing" premium tier. |
| ML (Docling, Marker, Surya) | Excellent | OSS, **GPU/server** | Not phone-feasible; server-side only. |

## Future options (not in the core)

- **Tagged-PDF fast path**: when `documentCatalog.structureTreeRoot` has real
  `H*`/`P`/`L` tags, use them directly (skip heuristics). Low hit rate in the wild
  (~1–16%) but a quality ceiling when present.
- **Scanned PDFs** (`hasText == false`): route to on-device **ML Kit Text
  Recognition v2**, then run the same line→block heuristics on its geometry.
- **Multi-column**: x-clustering to detect a gutter and read column-by-column.
  Deferred (most books are single-column; academic papers benefit).
- **Optional cloud "Enhanced parsing"**: Azure Document Intelligence Layout for
  hard/multi-column PDFs, gated behind an explicit opt-in (hybrid model).

## Key sources
- PdfBox `PDFTextStripper` params/flags: https://pdfbox.apache.org/docs/2.0.13/javadocs/org/apache/pdfbox/text/PDFTextStripper.html
- Styled/structured stripping recipe: https://github.com/mkl-public/testarea-pdfbox1/blob/master/src/main/java/mkl/testarea/pdfbox1/extract/PDFStyledTextStripper.java
- MuPDF AGPL: https://mupdf.readthedocs.io/en/1.26.11/license.html
- Pdfium reading-order limitation: https://groups.google.com/g/pdfium-bugs/c/5NHsS3fh_OQ
- Tagged-PDF prevalence: https://arxiv.org/html/2503.22216v1
- Immersive Reader patent (coordinate+font heuristics): https://image-ppubs.uspto.gov/dirsearch-public/print/downloadPdf/9658991
- Adobe Liquid Mode (ML): https://medium.com/adobetech/adobe-sensei-makes-responsive-pdf-experiences-with-liquid-mode-562320362e2a
- Azure / Textract / Document AI pricing: https://azure.microsoft.com/en-us/pricing/details/document-intelligence/
- ML Kit Text Recognition v2 (on-device, for scans): https://developers.google.com/ml-kit/vision/text-recognition/v2/android
