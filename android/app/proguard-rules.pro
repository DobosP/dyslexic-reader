# PdfBox-Android (com.tom-roush) uses reflection for fonts, encodings and
# resource loading; keep it intact so R8 doesn't strip required classes.
-keep class com.tom_roush.** { *; }
-dontwarn com.tom_roush.**

# Bouncy Castle is an optional PdfBox dependency (encrypted PDFs). Suppress
# warnings if it isn't on the classpath.
-dontwarn org.bouncycastle.**

# Google ML Kit text recognition: we bundle only the Latin model, but the
# plugin references the other script recognizers (Chinese/Devanagari/Japanese/
# Korean) which aren't on the classpath. Keep what we use; ignore the rest.
-keep class com.google.mlkit.vision.text.** { *; }
-dontwarn com.google.mlkit.**

# ONNX Runtime (mobile_ocr / PaddleOCR PP-OCRv5). Keep the JNI bridge classes
# and ignore optional references R8 can't resolve.
-keep class ai.onnxruntime.** { *; }
-dontwarn ai.onnxruntime.**
