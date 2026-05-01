plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.easylocation.app"
    compileSdk = 36 
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // --- ACTIVATION DU DESUGARING ---
        isCoreLibraryDesugaringEnabled = true 
        
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    // Le bloc kotlin moderne
    kotlin {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        }
    }

    defaultConfig {
        applicationId = "com.easylocation.app"
        
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        
        // --- ACTIVATION DU MULTIDEX ---
        multiDexEnabled = true 
        
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        resValue("string", "app_name", "EasyLocation")
    }

    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false 
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }

        getByName("debug") {
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }

    // CORRECTION ICI : Utilisation de KotlinCompile au lieu de KotlinJvmCompile
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        }
    }

    tasks.withType<JavaCompile>().configureEach {
        sourceCompatibility = "17"
        targetCompatibility = "17"
    }
}

flutter {
    source = "../.."
}

dependencies {
    // --- BIBLIOTHÈQUE DE DESUGARING (MISE À JOUR ✅) ---
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}