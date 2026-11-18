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
        // Run numbers restarted at 1 when the project moved to a fresh repo, so add 1000
        // to stay above every earlier test build and keep installing over it.
        val build = 1000 + (System.getenv("GITHUB_RUN_NUMBER") ?: "0").toInt()
        versionCode = build
        versionName = "0.1.$build"
    }

    // Lists the app's languages (one per res/values-xx folder) for Android 13's per-app language
    // setting, so people can run the app in another language than the phone's. See
    // docs/translations.md; src/main/res/resources.properties names the default (English).
    androidResources {
        generateLocaleConfig = true
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
    implementation("androidx.core:core:1.13.1")
}

// The page-hiding script and the Tree App list live in ../shared so an iOS app can use the same files.
android.sourceSets.getByName("main").assets.srcDirs("../../shared")

// The WikiTree Browser Extension's webview build, from the WBE release named in shared/wbe.lock,
// unpacked into shared/wbe/ (so into the assets above, under wbe/). See docs/wbe.md.
val fetchWbe by tasks.registering(Exec::class) {
    val root = rootProject.projectDir.parentFile
    workingDir = root
    commandLine("bash", "scripts/fetch-wbe.sh")
    inputs.file(File(root, "shared/wbe.lock"))
    inputs.property("wbeZip", System.getenv("WBE_ZIP") ?: "")
    outputs.file(File(root, "shared/wbe/.source"))
}
tasks.named("preBuild") { dependsOn(fetchWbe) }
