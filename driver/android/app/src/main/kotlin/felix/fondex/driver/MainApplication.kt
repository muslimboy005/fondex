package felix.fondex.driver

import android.app.Application
import com.yandex.mapkit.MapKitFactory

class MainApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        // Initialize Yandex MapKit with API key
        MapKitFactory.setApiKey("9bd1fb94-3024-43a3-9d31-44ecc894e42f")
    }
}

