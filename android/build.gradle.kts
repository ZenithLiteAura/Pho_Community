allprojects {
    repositories {
        google()
        mavenCentral()
        flatDir {
            dirs("libs") // 在libs目录下寻找.aar文件
        }
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
subprojects {
    pluginManager.withPlugin("com.android.library") {
        val androidExt = extensions.findByName("android") as? com.android.build.gradle.LibraryExtension
        androidExt?.let {
            if (it.namespace == null && project.group.toString().isNotEmpty()) {
                it.namespace = project.group.toString()
            }
        }
        tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
            compilerOptions {
                jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
            }
        }
    }
    afterEvaluate {
        if (project.path != ":app") {
            val androidExt = extensions.findByName("android") as? com.android.build.gradle.LibraryExtension
            androidExt?.compileOptions {
                sourceCompatibility = JavaVersion.VERSION_17
                targetCompatibility = JavaVersion.VERSION_17
            }
            // 强制覆盖子项目 Kotlin 编译 jvmTarget = 17（Flutter SDK 工具要求）
            // 插件自身的 kotlinOptions block 在评估时设置 jvmTarget=11 会覆盖上面的 configureEach，
            // 所以在 afterEvaluate 里再设置一次以确保 17 生效
            tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
                compilerOptions {
                    jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
                }
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
