# Razorpay ProGuard Rules
-keep class com.razorpay.** { *; }
-keep class com.razorpay.checkout.** { *; }
-dontwarn com.razorpay.**

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep Razorpay SDK classes
-keep class com.razorpay.** { *; }
-keepclassmembers class * {
    @com.razorpay.** *;
}

# Keep mbrainSDK related classes if any
-keep class **.mbrainSDK.** { *; }
-dontwarn **.mbrainSDK.**

# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

