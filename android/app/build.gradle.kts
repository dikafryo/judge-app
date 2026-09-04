import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

/**
 * 릴리스 서명 설정. neisme-knight 와 같은 방식이다.
 *
 * 키는 저장소 밖(`~/.config/judge-app/`)에 두고, 다른 환경에서는 JUDGE_APP_KEY_PROPERTIES 로
 * 경로를 지정한다. 키가 없으면 디버그 키로 슬쩍 서명해 배포되는 사고가 나지 않도록,
 * 릴리스 산출물을 만들려는 순간 빌드를 실패시킨다.
 */
val releaseSigningPropertiesFile: File = file(
    System.getenv("JUDGE_APP_KEY_PROPERTIES")
        ?: "${System.getProperty("user.home")}/.config/judge-app/key.properties"
)
val hasReleaseSigning: Boolean = releaseSigningPropertiesFile.isFile

val releaseSigningProperties: Properties = Properties().apply {
    if (hasReleaseSigning) {
        releaseSigningPropertiesFile.inputStream().use { load(it) }
    }
}

fun releaseSigningProperty(key: String): String =
    releaseSigningProperties.getProperty(key)
        ?: throw GradleException("릴리스 서명 설정에 '$key' 가 없습니다: $releaseSigningPropertiesFile")

android {
    namespace = "kr.sw4u.judge_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // 출시 후에는 바꿀 수 없는 앱 고유 식별자.
        applicationId = "kr.sw4u.judge_app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                keyAlias = releaseSigningProperty("keyAlias")
                keyPassword = releaseSigningProperty("keyPassword")
                storeFile = file(releaseSigningProperty("storeFile"))
                storePassword = releaseSigningProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("release")
        }
    }
}

// 키 없이 릴리스 APK/AAB 를 만들려 하면 미서명 산출물이 나오므로, 아예 빌드를 멈춘다.
gradle.taskGraph.whenReady {
    val requestsReleaseArtifact = allTasks.any { task ->
        task.name.contains("Release") &&
            (task.name.startsWith("assemble") ||
                task.name.startsWith("bundle") ||
                task.name.startsWith("package") ||
                task.name.startsWith("sign"))
    }

    if (requestsReleaseArtifact && !hasReleaseSigning) {
        throw GradleException(
            "릴리스 서명 키를 찾을 수 없습니다: $releaseSigningPropertiesFile\n" +
                "README 의 'Android 릴리스 서명' 절을 따라 키를 만든 뒤 다시 시도하세요."
        )
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
