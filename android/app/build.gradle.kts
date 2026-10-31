plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "app.qi.chat"
    compileSdk = flutter.compileSdkVersion
    // 不显式声明 ndkVersion：让 AGP 自动使用已安装的 NDK。
    // 注意本项目**确实需要** NDK 和 CMake（jni 依赖会编 C++），
    // 首次构建前请装好：
    //   sdkmanager "ndk;28.2.13676358" "cmake;3.22.1"

    compileOptions {
        // flutter_local_notifications 要求开启 core library desugaring，
        // 否则构建直接报错（它用了 java.time 等较新的 API）。
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "app.qi.chat"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: 正式发布前换成你自己的签名配置。
            // 现在先用调试签名，保证 `flutter run --release` 能跑。
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    signingConfigs {
        getByName("debug") {
            // 调试证书放在工程内而不是 C:\Users\<你>\.android\，
            // 这样构建不依赖用户目录的写权限，换机器也能直接编。
            storeFile = file("debug.keystore")
            storePassword = "android"
            keyAlias = "androiddebugkey"
            keyPassword = "android"
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}
