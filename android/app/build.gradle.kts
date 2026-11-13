plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "org.wikitree.treeapps"
    compileSdk = 35

    defaultConfig {
        // Placeholder id for testing. Pick the final id before the first store upload,
        // because it can never change after that.
        applicationId = "org.wikitree.treeapps"
        minSdk = 26
        targetSdk = 35
        versionCode = (System.getenv("GITHUB_RUN_NUMBER") ?: "1").toInt()
        versionName = "0.1." + (System.getenv("GITHUB_RUN_NUMBER") ?: "0")
    }

    signingConfigs {
        // A fixed key for test builds only, so each new test APK installs over the last one.
        // Store releases must use a separate private key kept out of the repo.
        create("testing") {
            storeFile = file("testing.keystore")
            storePassword = "android"
            keyAlias = "testing"
            keyPassword = "android"
        }
    }

    buildTypes {
        debug {
            signingConfig = signingConfigs.getByName("testing")
        }
        release {
            isMinifyEnabled = false
            signingConfig = signingConfigs.getByName("testing")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = "17"
    }
}

dependencies {
    implementation("androidx.webkit:webkit:1.12.1")
    implementation("androidx.browser:browser:1.8.0")
}

// The page-hiding script and the Tree App list live in ../shared so an iOS app can use the same files.
android.sourceSets.getByName("main").assets.srcDirs("../../shared")
