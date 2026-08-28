plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.swansport.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // SwanSport'un yayın kimliği. Google Play'e bir kez yüklendikten
        // sonra DEĞİŞTİRİLEMEZ — değiştirmek ayrı bir uygulama demektir.
        applicationId = "com.swansport.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // YAYIN İMZASI HENÜZ TANIMLI DEĞİL.
            //
            // Şu an hata ayıklama anahtarıyla imzalanıyor; bu APK yan yükleme
            // (sideload) ile kurulabilir ama Google Play'e YÜKLENEMEZ ve
            // güvenilir bir dağıtım için uygun değildir.
            //
            // Play'e çıkarken yapılacaklar:
            //   1. Anahtar üret:
            //      keytool -genkey -v -keystore swansport-release.jks             //        -keyalg RSA -keysize 2048 -validity 10000 -alias swansport
            //   2. `android/key.properties` oluştur (ASLA depoya ekleme,
            //      .gitignore'a gireceğinden emin ol):
            //        storeFile=../swansport-release.jks
            //        storePassword=...
            //        keyPassword=...
            //        keyAlias=swansport
            //   3. Bu bloğu key.properties'ten okuyan bir signingConfig'e çevir.
            //
            // Anahtar dosyası ve parolalar kaybedilirse uygulamanın
            // güncellenmesi mümkün olmaz; yedeğini güvenli bir yerde tut.
            signingConfig = signingConfigs.getByName("debug")
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
