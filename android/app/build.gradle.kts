plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services") // Plugin de Firebase
}

android {
    namespace = "com.muni.incidencias"
    compileSdk = flutter.compileSdkVersion

    // 🔧 OBLIGATORIO: usar NDK 27.0.12077973 (Firebase lo exige)
    ndkVersion = "27.0.12077973"

    defaultConfig {
        applicationId = "com.muni.incidencias"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Temporal: firma debug
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    // 🔧 OBLIGATORIO: habilitar desugaring
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "11"
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Firebase (BOM)
    implementation(platform("com.google.firebase:firebase-bom:33.3.0"))
    implementation("com.google.firebase:firebase-analytics")

    // 🔧 OBLIGATORIO: librería para desugaring
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}
