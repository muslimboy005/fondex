package felix.fondex.driver

import android.app.Application
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.pm.PackageManager
import android.os.Build

class MainApplication : Application() {
    override fun onCreate() {
        super.onCreate()

        // Must run before BackgroundService.onCreate() — BootReceiver fires on
        // MY_PACKAGE_REPLACED (every `adb install -r`) and starts the FGS before
        // any Dart code runs, so the channel must be registered natively.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "order_listener_channel",
                "Order listener",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Yangi zakazlar kuzatilishi uchun fon xizmati"
                setSound(null, null)
                enableVibration(false)
            }
            getSystemService(NotificationManager::class.java)
                ?.createNotificationChannel(channel)
        }

        try {
            val appInfo = packageManager.getApplicationInfo(packageName, PackageManager.GET_META_DATA)
            val metaData = appInfo.metaData
            val apiKey = metaData?.getString("com.yandex.mapkit.api.key")
                ?: metaData?.getString("com.yandex.maps.api.key")
            if (!apiKey.isNullOrBlank()) {
                val mapKitFactory = Class.forName("com.yandex.mapkit.MapKitFactory")
                val setApiKey = mapKitFactory.getMethod("setApiKey", String::class.java)
                setApiKey.invoke(null, apiKey)
            }
        } catch (_: Throwable) {
        }
    }
}
