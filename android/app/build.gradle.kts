import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
}

// Chave de upload da Play Store, fora do Git (android/key.properties):
//   storePassword=...  keyPassword=...  keyAlias=upload  storeFile=/caminho/upload.jks
// Sem o arquivo, o release só é gerado com ALLOW_DEBUG_SIGNED_RELEASE=true
// (APK interno de homologação), nunca para envio à loja.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val hasReleaseKeystore = keystorePropertiesFile.exists()
if (hasReleaseKeystore) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}
val allowDebugSignedRelease =
    (System.getenv("ALLOW_DEBUG_SIGNED_RELEASE") ?: "false") == "true"

android {
    namespace = "app.pediatria360"
    // Plugins (google_sign_in_android, package_info_plus) pedem SDK 36+.
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "app.pediatria360"
        // firebase_auth exige API 23+
        minSdk = maxOf(23, flutter.minSdkVersion)
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = when {
                hasReleaseKeystore -> signingConfigs.getByName("release")
                allowDebugSignedRelease -> signingConfigs.getByName("debug")
                else -> null
            }
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

gradle.taskGraph.whenReady {
    val buildsRelease = allTasks.any {
        it.project == project &&
            (it.name == "assembleRelease" || it.name == "bundleRelease")
    }
    if (buildsRelease && !hasReleaseKeystore && !allowDebugSignedRelease) {
        throw GradleException(
            "Release sem android/key.properties. Crie a chave de upload " +
                "(veja PUBLICACAO_PENDENCIAS_USUARIO.md) ou, só para APK " +
                "interno de homologação, defina ALLOW_DEBUG_SIGNED_RELEASE=true."
        )
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.2")
    implementation("androidx.multidex:multidex:2.0.1")
}
