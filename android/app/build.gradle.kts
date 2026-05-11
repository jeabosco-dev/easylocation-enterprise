plugins {
    id("com.android.application")
    // CORRECTION : On remplace "kotlin-android" par l'identifiant moderne
    id("org.jetbrains.kotlin.android") 
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.easylocation.app"
    
    // Mise à jour vers le SDK 36 pour compatibilité avec vos plugins récents
    compileSdk = 36 
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true 
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlin {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        }
    }

    defaultConfig {
        applicationId = "com.easylocation.app"
        minSdk = flutter.minSdkVersion
        
        // Aligné sur compileSdk pour éviter les avertissements de version
        targetSdk = 36 
        
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
}

// --- CES BLOCS DOIVENT ÊTRE EN DEHORS DE 'android' ---

tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }
}

tasks.withType<JavaCompile>().configureEach {
    sourceCompatibility = "17"
    targetCompatibility = "17"
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}