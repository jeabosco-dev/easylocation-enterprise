pluginManagement {
    val localProperties = java.util.Properties()
    val localPropertiesFile = File(rootProject.projectDir, "local.properties")
    if (localPropertiesFile.exists()) {
        localPropertiesFile.inputStream().use { localProperties.load(it) }
    }

    val flutterSdkPath = localProperties.getProperty("flutter.sdk")
        ?: throw GradleException("Le chemin flutter.sdk n'est pas défini dans local.properties")

    // On dit à Gradle où chercher les outils Flutter AVANT de charger les plugins
    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    // Mise à jour vers la version recommandée par Flutter (8.11.1)
    id("com.android.application") version "8.11.1" apply false
    // Mise à jour vers la version recommandée de Kotlin (2.2.20)
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
}

include(":app")