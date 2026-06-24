package com.dobosp.dyslexic_reader

import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.pdf.PdfRenderer
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.os.ParcelFileDescriptor
import android.provider.OpenableColumns
import com.tom_roush.pdfbox.android.PDFBoxResourceLoader
import com.tom_roush.pdfbox.pdmodel.PDDocument
import com.tom_roush.pdfbox.pdmodel.interactive.documentnavigation.outline.PDOutlineItem
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.concurrent.Executors

/**
 * Hosts the native PDF bridge: text extraction (PdfBox-Android) and page
 * rendering (Android PdfRenderer), plus open-with / share intent handling.
 * The Dart side is [PdfTextChannel] and [IncomingFileChannel]. Word-boundary
 * TTS will add a channel in a later phase. See docs/ARCHITECTURE.md §5.
 */
class MainActivity : FlutterActivity() {
    private val pdfChannelName = "dyslexic_reader/pdf_text"
    private val incomingChannelName = "dyslexic_reader/incoming"
    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    /** A file the app was opened with (VIEW/SEND), consumed once by Flutter. */
    private var pendingFile: Map<String, String>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        PDFBoxResourceLoader.init(applicationContext)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, pdfChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "extractText" -> {
                        val path = call.argument<String>("path")
                        val password = call.argument<String>("password")
                        if (path.isNullOrEmpty()) {
                            result.error("ARG", "path is required", null)
                        } else {
                            extractText(path, password, result)
                        }
                    }
                    "renderPage" -> {
                        val path = call.argument<String>("path")
                        val pageIndex = call.argument<Int>("pageIndex") ?: 0
                        val targetWidth = call.argument<Int>("targetWidth") ?: 1080
                        if (path.isNullOrEmpty()) {
                            result.error("ARG", "path is required", null)
                        } else {
                            renderPage(path, pageIndex, targetWidth, result)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, incomingChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "consumeInitialFile" -> {
                        val file = pendingFile
                        pendingFile = null
                        result.success(file)
                    }
                    else -> result.notImplemented()
                }
            }

        // The intent that launched the activity (cold-start open-with/share).
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
    }

    @Suppress("DEPRECATION")
    private fun handleIntent(intent: Intent?) {
        if (intent == null) return
        when (intent.action) {
            Intent.ACTION_VIEW ->
                intent.data?.let { uri -> pendingFile = resolveUri(uri) }
            Intent.ACTION_SEND -> {
                val uri = intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
                if (uri != null) {
                    pendingFile = resolveUri(uri)
                } else {
                    val text = intent.getCharSequenceExtra(Intent.EXTRA_TEXT)?.toString()
                    if (!text.isNullOrBlank()) pendingFile = writeSharedText(text)
                }
            }
        }
    }

    private fun writeSharedText(text: String): Map<String, String>? = try {
        val out = File(cacheDir, "shared_${System.currentTimeMillis()}.txt")
        out.writeText(text)
        mapOf("path" to out.absolutePath, "name" to "Shared text.txt")
    } catch (e: Exception) {
        null
    }

    private fun resolveUri(uri: Uri): Map<String, String> {
        return try {
            val name = queryName(uri) ?: "document"
            val outFile = File(cacheDir, "incoming_${System.currentTimeMillis()}_${sanitize(name)}")
            val input = contentResolver.openInputStream(uri)
                ?: return mapOf("error" to "Could not open the file (no input stream).")
            input.use { source ->
                outFile.outputStream().use { sink -> source.copyTo(sink) }
            }
            mapOf("path" to outFile.absolutePath, "name" to name)
        } catch (e: Exception) {
            mapOf("error" to "${e.javaClass.simpleName}: ${e.message ?: "unknown"}")
        }
    }

    private fun sanitize(name: String): String =
        name.replace(Regex("[^A-Za-z0-9._-]"), "_").take(80)

    private fun queryName(uri: Uri): String? {
        if (uri.scheme == "file") return uri.path?.let { File(it).name }
        var name: String? = null
        contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
            ?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                    if (index >= 0) name = cursor.getString(index)
                }
            }
        return name
    }

    private fun extractText(path: String, password: String?, result: MethodChannel.Result) {
        // PDF parsing is blocking — keep it off the platform thread.
        executor.execute {
            try {
                val file = File(path)
                val document = if (password.isNullOrEmpty()) {
                    PDDocument.load(file)
                } else {
                    PDDocument.load(file, password)
                }
                document.use { doc ->
                    val stripper = StructuredTextStripper()
                    stripper.getText(doc) // side effect: collects line geometry
                    val blocks = stripper.buildBlocks()
                    val payload = mapOf(
                        "blocks" to blocks,
                        "pageCount" to doc.numberOfPages,
                        "hasText" to blocks.isNotEmpty(),
                        "outline" to extractOutline(doc),
                    )
                    mainHandler.post { result.success(payload) }
                }
            } catch (e: Exception) {
                mainHandler.post {
                    result.error("EXTRACT_FAILED", e.message ?: "PDF extraction failed", null)
                }
            }
        }
    }

    private fun extractOutline(doc: PDDocument): List<Map<String, Any>> {
        val root = doc.documentCatalog.documentOutline ?: return emptyList()
        val out = mutableListOf<Map<String, Any>>()

        fun visit(item: PDOutlineItem?, level: Int) {
            var cur = item
            while (cur != null) {
                val title = cur.title?.trim().orEmpty()
                val page = outlinePageIndex(doc, cur)
                if (title.isNotEmpty() && page >= 0) {
                    out.add(
                        mapOf(
                            "title" to title,
                            "level" to level.coerceIn(1, 3),
                            "page" to page,
                        )
                    )
                }
                visit(cur.firstChild, level + 1)
                cur = cur.nextSibling
            }
        }

        visit(root.firstChild, 1)
        return out
    }

    private fun outlinePageIndex(doc: PDDocument, item: PDOutlineItem): Int {
        val page = item.findDestinationPage(doc) ?: return -1
        return doc.pages.indexOf(page)
    }

    private fun renderPage(
        path: String,
        pageIndex: Int,
        targetWidth: Int,
        result: MethodChannel.Result,
    ) {
        executor.execute {
            var pfd: ParcelFileDescriptor? = null
            try {
                pfd = ParcelFileDescriptor.open(File(path), ParcelFileDescriptor.MODE_READ_ONLY)
                PdfRenderer(pfd).use { renderer ->
                    if (pageIndex < 0 || pageIndex >= renderer.pageCount) {
                        mainHandler.post { result.error("RANGE", "page out of range", null) }
                        return@execute
                    }
                    renderer.openPage(pageIndex).use { page ->
                        val width = targetWidth.coerceAtLeast(1)
                        val scale = width.toFloat() / page.width
                        val height = (page.height * scale).toInt().coerceAtLeast(1)
                        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
                        bitmap.eraseColor(Color.WHITE)
                        page.render(bitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                        val stream = ByteArrayOutputStream()
                        bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
                        bitmap.recycle()
                        val bytes = stream.toByteArray()
                        mainHandler.post { result.success(bytes) }
                    }
                }
            } catch (e: Exception) {
                mainHandler.post {
                    result.error("RENDER_FAILED", e.message ?: "PDF render failed", null)
                }
            } finally {
                try {
                    pfd?.close()
                } catch (_: Exception) {
                }
            }
        }
    }
}
