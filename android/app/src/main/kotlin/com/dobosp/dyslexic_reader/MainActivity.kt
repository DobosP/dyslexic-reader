package com.dobosp.dyslexic_reader

import android.os.Handler
import android.os.Looper
import com.tom_roush.pdfbox.android.PDFBoxResourceLoader
import com.tom_roush.pdfbox.pdmodel.PDDocument
import com.tom_roush.pdfbox.text.PDFTextStripper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

/**
 * Hosts the native PDF text-extraction bridge (PdfBox-Android). The reflow
 * pipeline calls [PdfTextChannel] on the Dart side; word-boundary TTS will add
 * a second channel in a later phase. See docs/ARCHITECTURE.md §5.
 */
class MainActivity : FlutterActivity() {
    private val channelName = "dyslexic_reader/pdf_text"
    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Loads PdfBox font/resource data on first use.
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
}
