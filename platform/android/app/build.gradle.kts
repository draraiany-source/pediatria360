// Trecho a MESCLAR em android/app/build.gradle.kts.
//
// Três pontos que o scaffolding padrão não cobre e que causam falha de build
// ou de execução com esta combinação de dependências:

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    // Sem estes dois, o Firebase não é configurado no build.
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
}

android {
    namespace = "app.pediatria360"
    compileSdk = 35
    ndkVersion = "27.0.12077973"

    compileOptions {
        // Necessário para flutter_local_notifications em minSdk baixo.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "app.pediatria360"
        // firebase_auth exige 23. O padrão do Flutter é menor e o build quebra.
        minSdk = 23
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // O conjunto Firebase + Riverpod + fl_chart passa de 64k métodos.
        multiDexEnabled = true
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug") // troque na publicação
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.2")
    implementation("androidx.multidex:multidex:2.0.1")
}
