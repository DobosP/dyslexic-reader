package com.dobosp.dyslexic_reader

import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.pdf.PdfRenderer
import android.os.Handler
import android.os.Looper
import android.os.ParcelFileDescriptor
import com.tom_roush.pdfbox.android.PDFBoxResourceLoader
import com.tom_roush.pdfbox.pdmodel.PDDocument
import com.tom_roush.pdfbox.text.PDFTextStripper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.concurrent.Executors

/**
 * Hosts the native PDF bridge: text extraction (PdfBox-Android) and page
 * rendering (Android PdfRenderer). The Dart side is [PdfTextChannel].
 * Word-boundary TTS will add a second channel in a later phase. See
 * docs/ARCHITECTURE.md §5.
 */
class MainActivity : FlutterActivity() {
    private val channelName = "dyslexic_reader/pdf_text"
    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        PDFBoxResourceLoader.init(applicationContext)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
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
                    val stripper = PDFTextStripper().apply { sortByPosition = true }
                    val text = stripper.getText(doc)
                    val payload = mapOf(
                        "fullText" to text,
                        "pageCount" to doc.numberOfPages,
                        "hasText" to text.trim().isNotEmpty(),
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
