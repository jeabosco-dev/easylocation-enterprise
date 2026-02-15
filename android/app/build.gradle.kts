plugins {
    id("com.android.application")
    id("kotlin-android")
    // Le plugin Flutter Gradle doit être appliqué après les plugins Android et Kotlin.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.easylocation_mvp"
    
    // Changement nécessaire pour résoudre le conflit des bibliothèques AndroidX
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    // Migration vers compilerOptions pour Kotlin
    kotlin {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        }
    }

    defaultConfig {
        applicationId = "com.example.easylocation_mvp"
        minSdk = 24
        // targetSdk reste à 35 pour éviter des changements de comportement système imprévus
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    // Sécurité supplémentaire pour forcer Java 17 sur toutes les tâches de compilation Kotlin
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