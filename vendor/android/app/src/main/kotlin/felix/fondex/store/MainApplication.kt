package felix.fondex.store

import android.app.Application
import android.content.pm.PackageManager

class MainApplication : Application() {
    override fun onCreate() {
        super.onCreate()
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
