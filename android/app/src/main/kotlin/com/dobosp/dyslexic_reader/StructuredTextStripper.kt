package com.dobosp.dyslexic_reader

import com.tom_roush.pdfbox.pdmodel.PDPage
import com.tom_roush.pdfbox.text.PDFTextStripper
import com.tom_roush.pdfbox.text.TextPosition
import kotlin.math.roundToInt

/** A line of text with geometry + style, collected while stripping. */
private data class LineInfo(
    val page: Int,
    val text: String,
    val top: Float,
    val leftX: Float,
    val size: Float,
    val isBold: Boolean,
)

/**
 * Reconstructs document structure from per-glyph geometry, font sizes, and font
 * weight instead of returning flat text. Emits {"type": "h1"|"h2"|"h3"|"p",
 * "text": ...} blocks.
 *
 * Heading detection is PRECISION-FIRST and multi-signal (no fixed size ratios):
 *  - body size is data-derived (char-mass mode); heading tiers come from
 *    clustering the distinct larger sizes (H1>H2>H3), not hard-coded ratios;
 *  - a line is promoted only when a strong cue (clearly-larger size OR a
 *    majority-bold line OR a section number) co-occurs with brevity, no
 *    trailing comma/colon, and — for bold-at-body-size — whitespace isolation.
 * This keeps body text (and lines with a few bold words) from being promoted.
 *
 * Run [PDFTextStripper.getText] then call [buildBlocks].
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
        var boldCount = 0
        for (tp in textPositions) {
            val s = tp.fontSizeInPt.roundToInt()
            sizeCounts[s] = (sizeCounts[s] ?: 0) + 1
            if (tp.yDirAdj < top) top = tp.yDirAdj
            if (isBoldGlyph(tp)) boldCount++
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
                isBold = boldCount * 2 >= textPositions.size, // line is majority-bold
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
        val tiers = headingTiers(kept, bodySize)

        // Classify every line up front (needs neighbour context for isolation).
        val types = ArrayList<String>(kept.size)
        for (i in kept.indices) types.add(classify(kept, i, tiers, medianAdvance))

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

        for (i in kept.indices) {
            val line = kept[i]
            val type = types[i]
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
     * Precision-first, multi-signal classification. Returns "h1"/"h2"/"h3" only
     * when a strong cue agrees with the corroborating signals; otherwise "p".
     */
    private fun classify(
        lines: List<LineInfo>,
        i: Int,
        tiers: List<Float>,
        medianAdvance: Float,
    ): String {
        val line = lines[i]
        val t = line.text
        val wordCount = t.split(WS).size
        val sizeTier = tierOf(line.size, tiers)            // -1 == body size
        val brief = wordCount <= 14 && t.length <= 90
        val endsBad = t.endsWith(",") || t.endsWith(":") || t.endsWith(";")
        val numbering = numberingDepth(t)                  // 0, or section depth 1..3

        val isoAbove = i > 0 && lines[i - 1].page == line.page &&
            (line.top - lines[i - 1].top) > 1.5f * medianAdvance
        val isoBelow = i < lines.size - 1 && lines[i + 1].page == line.page &&
            (lines[i + 1].top - line.top) > 1.5f * medianAdvance
        val isolated = medianAdvance <= 0f || isoAbove || isoBelow

        val sizeHeading = sizeTier >= 0 && brief && !endsBad
        val boldHeading = line.isBold && sizeTier < 0 && brief && isolated && !endsBad
        val numHeading = numbering in 1..3 && (sizeTier >= 0 || line.isBold) && brief && !endsBad

        if (!(sizeHeading || boldHeading || numHeading)) return "p"

        // Section numbering is the most reliable level cue; else size tier; else
        // a bold-only line is treated as a subsection.
        val level = when {
            numbering in 1..3 -> numbering - 1
            sizeTier >= 0 -> sizeTier
            else -> 1
        }
        return "h" + (level + 1).coerceIn(1, 3)
    }

    /**
     * Heading size tiers: distinct rounded sizes strictly larger than body,
     * merged within 1pt, dropping one-off sizes, largest first (tiers[0]=H1).
     */
    private fun headingTiers(lines: List<LineInfo>, bodySize: Float): List<Float> {
        val countBySize = HashMap<Int, Int>()
        for (l in lines) {
            val k = l.size.roundToInt()
            if (k > bodySize + 0.5f) countBySize[k] = (countBySize[k] ?: 0) + 1
        }
        var sizes = countBySize.filterValues { it >= 2 }.keys.toMutableList()
        if (sizes.isEmpty()) sizes = countBySize.keys.toMutableList()
        sizes.sortDescending()
        val tiers = mutableListOf<Float>()
        for (s in sizes) {
            if (tiers.isEmpty() || tiers.last() - s > 1.0f) tiers.add(s.toFloat())
            if (tiers.size == 3) break
        }
        return tiers
    }

    private fun tierOf(size: Float, tiers: List<Float>): Int {
        for (i in tiers.indices) {
            if (size >= tiers[i] - 0.5f) return i
        }
        return -1
    }

    /** Section-number depth ("1." -> 1, "1.1" -> 2, "2.3.4" -> 3); 0 if none. */
    private fun numberingDepth(text: String): Int {
        val m = NUMBERING.find(text) ?: return 0
        val num = m.groupValues[1]
        val after = text.getOrNull(num.length)
        val hadPunct = after == '.' || after == ')'
        val parts = num.split('.').size
        // A bare single number with no '.'/')' (e.g. a year) is too ambiguous.
        if (parts == 1 && !hadPunct) return 0
        return parts.coerceAtMost(3)
    }

    private fun isBoldGlyph(tp: TextPosition): Boolean {
        val font = tp.font ?: return false
        val name = font.name
        if (name != null && BOLD_NAME.containsMatchIn(name)) return true
        val d = font.fontDescriptor ?: return false
        return d.isForceBold || d.fontWeight >= 600f
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

    private companion object {
        val WS = Regex("\\s+")
        val BOLD_NAME = Regex("(?i)bold|black|heavy|semibold|demibold")
        // Leading section number: "1." "2)" "1.1" "2.3.4" then space then content.
        val NUMBERING = Regex("^(\\d+(?:\\.\\d+)*)[.)]?\\s+\\S")
    }
}
