# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# ✅ Ignorar clases de Play Core que R8 busca pero no existen en APK directa
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }

# sqflite
-keep class com.tekartik.sqflite.** { *; }

# encrypt / AES
-keep class com.sun.crypto.** { *; }
-keep class javax.crypto.** { *; }

# device_info_plus
-keep class dev.fluttercommunity.plus.device_info.** { *; }

# share_plus
-keep class dev.fluttercommunity.plus.share.** { *; }

# file_picker
-keep class com.mr.flutter.plugin.filepicker.** { *; }

# Modelos de datos
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}