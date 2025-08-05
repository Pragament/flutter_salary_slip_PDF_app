# Keep necessary ML Kit classes
-keep class com.google.mlkit.vision.face.** { *; }
-keep class com.google.mlkit.vision.common.** { *; }
-keep class com.google.mlkit.common.** { *; }

# Keep TensorFlow Lite classes
-keep class org.tensorflow.lite.** { *; }
-keep class org.tensorflow.lite.gpu.** { *; }

# Exclude ML Kit Text Recognition
-dontwarn com.google.mlkit.vision.text.**
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# Add this line from missing_rules.txt
-dontwarn org.tensorflow.lite.gpu.GpuDelegateFactory$Options