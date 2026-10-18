# WorkManager creates WorkDatabase_Impl through reflection. R8 full mode
# (AGP 9, on for Flutter release) removes that constructor, and the process
# dies in androidx.startup.InitializationProvider before the first frame.
-keep class androidx.work.impl.WorkDatabase { *; }
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
