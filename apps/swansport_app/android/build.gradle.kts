allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
// Bazı eklentiler (ör. file_picker) hâlâ eski compileSdk ile geliyor; Flutter
// 3.44 ise en az 36 istiyor. Tüm kitaplık modüllerini 36'ya sabitle.
// NOT: Bu blok, aşağıdaki evaluationDependsOn'dan ÖNCE gelmeli — orası
// projeleri erkenden değerlendirdiği için afterEvaluate sonrasında çalışmaz.
subprojects {
    afterEvaluate {
        extensions.findByName("android")?.let { ext ->
            when (ext) {
                is com.android.build.gradle.LibraryExtension -> {
                    ext.compileSdk = 36
                }
                is com.android.build.gradle.BaseExtension -> {
                    ext.compileSdkVersion(36)
                }
            }
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
