plugins {
    id("com.android.application")
    id("kotlin-android")
    // Le plugin Flutter Gradle doit être appliqué après les plugins Android et Kotlin.
    id("dev.flutter.flutter-gradle-plugin")
    // PLUGIN GOOGLE SERVICES (Méthode moderne via bloc plugins)
    id("com.google.gms.google-services")
}

android {
    // Aligné sur le google-services.json
    namespace = "com.easylocation.app"
    
    // Aligné sur targetSdk pour une compatibilité parfaite des bibliothèques
    compileSdk = 35 
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    // Configuration Kotlin
    kotlin {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        }
    }

    defaultConfig {
        // Identifiant unique de l'application (Identique au projet Firebase)
        applicationId = "com.easylocation.app"
        
        // minSdk 24 est idéal pour supporter la WebView moderne et Firebase
        minSdk = 24
        targetSdk = 35
        
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Note : Utilise debug pour l'instant, mais devra être remplacé par une clé de prod plus tard
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    // Force Java 17 sur toutes les tâches de compilation Kotlin
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinJvmCompile>().configureEach {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        }
    }

    // Force Java 17 pour la compilation Java
    tasks.withType<JavaCompile>().configureEach {
        sourceCompatibility = "17"
        targetCompatibility = "17"
    }
}

flutter {
    source = "../.."
}