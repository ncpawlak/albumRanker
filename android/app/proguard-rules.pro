# R8 strips shared_preferences' coroutine-based Pigeon methods, which crashes
# release builds at startup with NoSuchMethodError on SharedPreferencesApiRegistrar.
-keep class io.flutter.plugins.sharedpreferences.** { *; }
-keep class kotlin.coroutines.** { *; }
-keep class kotlinx.coroutines.** { *; }
