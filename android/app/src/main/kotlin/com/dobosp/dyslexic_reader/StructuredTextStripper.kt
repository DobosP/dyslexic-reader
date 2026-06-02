package com.dobosp.dyslexic_reader

import com.tom_roush.pdfbox.pdmodel.PDPage
import com.tom_roush.pdfbox.text.PDFTextStripper
import com.tom_roush.pdfbox.text.TextPosition
import kotlin.math.roundToInt

/** A line of text with geometry, collected while stripping. */
private data class LineInfo(
    val page: Int,
    val text: String,
    val top: Float,
    val leftX: Float,
    val size: Float,
)

/**
 * Reconstructs document structure from per-glyph geometry + font sizes instead
 * of returning flat text. Emits {"type": "h1"|"h2"|"h3"|"p", "text": ...} blocks.
 *
 * Heading detection is intentionally CONSERVATIVE: only clearly-larger, short
 * lines (real chapter/section titles) become headings, so body text is never
 * promoted/bolded. Run [PDFTextStripper.getText] then call [buildBlocks].
 */
class StructuredTextStripper : PDFTextStripper() {
    private val lines = mutableListOf<LineInfo>()
    private val pageHeights = mutableMapOf<Int, Float>()

    init {
        sortByPosition = true
    }

    override fun startPage(page: PDPage) {
        pageHeights[currentPageNo] = page.mediaBox.height
        super.startPage(page)
    }

    override fun writeString(text: String, textPositions: List<TextPosition>) {
        if (textPositions.isEmpty()) return
        val trimmed = text.trim()
        if (trimmed.isEmpty()) return

        val sizeCounts = HashMap<Int, Int>()
        var top = Float.MAX_VALUE
        for (tp in textPositions) {
            val s = tp.fontSizeInPt.roundToInt()
            sizeCounts[s] = (sizeCounts[s] ?: 0) + 1
            if (tp.yDirAdj < top) top = tp.yDirAdj
        }
        val size = sizeCounts.maxByOrNull { it.value }?.key?.toFloat()
            ?: textPositions[0].fontSizeInPt
        lines.add(
            LineInfo(
                page = currentPageNo,
                text = trimmed,
                top = top,
                leftX = textPositions.first().xDirAdj,
                size = size,
            )
        )
    }

    /** Run the structure heuristics and return typed blocks. */
    fun buildBlocks(): List<Map<String, String>> {
        if (lines.isEmpty()) return emptyList()

        val kept = dropRunningHeadersFooters(lines)
        if (kept.isEmpty()) return emptyList()

        val bodySize = modeSize(kept)
        val medianAdvance = medianLineAdvance(kept)

        val blocks = mutableListOf<Map<String, String>>()
        var curType: String? = null
        val curText = StringBuilder()
        var prev: LineInfo? = null

        fun flush() {
            val type = curType
            if (type != null && curText.isNotBlank()) {
                blocks.add(mapOf("type" to type, "text" to curText.toString().trim()))
            }
            curText.setLength(0)
            curType = null
        }

        for (line in kept) {
            val type = classify(line, bodySize)
            val startNew = when {
                curType == null -> true
                curType == "p" && type == "p" && prev != null ->
                    isParagraphBreak(prev, line, medianAdvance)
                // merge consecutive heading lines of the same level (multi-line titles)
                curType != "p" && type == curType && prev != null &&
                    line.page == prev.page &&
                    (line.top - prev.top) in 0f..(2.4f * line.size) -> false
                else -> true
            }
            if (startNew) {
                flush()
                curType = type
                curText.append(line.text)
            } else {
                appendDeHyphenated(curText, line.text)
            }
            prev = line
        }
        flush()
        return blocks
    }

    /**
     * Conservative: a line is a heading only if it is clearly LARGER than body
     * text AND short. Body text is uniform size, so it stays "p" (never bolded).
     */
    private fun classify(line: LineInfo, bodySize: Float): String {
        val ratio = if (bodySize > 0f) line.size / bodySize else 1f
        val wordCount = line.text.split(Regex("\\s+")).size
        if (wordCount <= 14) {
            if (ratio >= 1.7f) return "h1"
            if (ratio >= 1.4f) return "h2"
            if (ratio >= 1.2f) return "h3"
        }
        return "p"
    }

    private fun isParagraphBreak(prev: LineInfo, line: LineInfo, medianAdvance: Float): Boolean {
        if (line.page != prev.page) return false // let paragraphs flow across pages
        val gap = line.top - prev.top
        if (medianAdvance > 0f && gap > 1.8f * medianAdvance) return true
        if (line.leftX - prev.leftX > 2f * avgSpace(line)) return true // first-line indent
        return false
    }

    private fun avgSpace(line: LineInfo): Float = (line.size * 0.25f).coerceAtLeast(1f)

    private fun appendDeHyphenated(sb: StringBuilder, next: String) {
        val len = sb.length
        if (len >= 2 && sb[len - 1] == '-' && sb[len - 2].isLetter()) {
            sb.setLength(len - 1) // drop the hyphen, join the split word
            sb.append(next)
        } else {
            sb.append(' ').append(next)
        }
    }

    private fun modeSize(lines: List<LineInfo>): Float {
        val counts = HashMap<Int, Int>()
        for (l in lines) {
            val k = l.size.roundToInt()
            counts[k] = (counts[k] ?: 0) + l.text.length
        }
        return counts.maxByOrNull { it.value }?.key?.toFloat() ?: 12f
    }

    private fun medianLineAdvance(lines: List<LineInfo>): Float {
        val advances = mutableListOf<Float>()
        for (i in 1 until lines.size) {
            if (lines[i].page == lines[i - 1].page) {
                val d = lines[i].top - lines[i - 1].top
                if (d > 0f) advances.add(d)
            }
        }
        if (advances.isEmpty()) return 0f
        advances.sort()
        return advances[advances.size / 2]
    }

    private fun dropRunningHeadersFooters(lines: List<LineInfo>): List<LineInfo> {
        if (lines.map { it.page }.toSet().size < 3) return lines
        val seenOnPages = HashMap<String, MutableSet<Int>>()
        for (l in lines) {
            val ph = pageHeights[l.page] ?: continue
            if (l.top < ph * 0.12f || l.top > ph * 0.88f) {
                val norm = normalize(l.text)
                if (norm.isNotEmpty()) {
                    seenOnPages.getOrPut(norm) { mutableSetOf() }.add(l.page)
                }
            }
        }
        val repeated = seenOnPages.filter { it.value.size >= 3 }.keys
        if (repeated.isEmpty()) return lines
        return lines.filter { l ->
            val ph = pageHeights[l.page]
            val nearEdge = ph != null && (l.top < ph * 0.12f || l.top > ph * 0.88f)
            !(nearEdge && repeated.contains(normalize(l.text)))
        }
    }

    private fun normalize(s: String): String =
        s.replace(Regex("\\d+"), "#").replace(Regex("\\s+"), " ").trim().lowercase()
}
