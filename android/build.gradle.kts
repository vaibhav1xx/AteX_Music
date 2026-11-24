import org.jetbrains.kotlin.gradle.dsl.JvmTarget
import org.jetbrains.kotlin.gradle.tasks.KotlinCompile

plugins {
    id("com.android.application") apply false
    id("com.android.library") apply false
    id("org.jetbrains.kotlin.android") apply false
}

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

// Subprojects configuration: Force Java 17 compileOptions, Kotlin JVM target 17,
// and AGP 8+ fallback namespace for all Android library subprojects (e.g. on_audio_query_android).
subprojects {
    // 1. Force JavaCompile tasks (compileReleaseJavaWithJavac, etc.) to target Java 17
    tasks.withType<JavaCompile>().configureEach {
        sourceCompatibility = "17"
        targetCompatibility = "17"
    }

    // 2. Force Kotlin compile tasks to JVM 17 using Kotlin 2.x compilerOptions.jvmTarget
    tasks.withType<KotlinCompile>().configureEach {
        compilerOptions.jvmTarget.set(JvmTarget.JVM_17)
    }

    // 3. Configure Android extensions before :app evaluation depends on them
    val configureAndroid = {
        val androidExt = project.extensions.findByName("android")
        if (androidExt != null) {
            // AGP 8+ namespace fallback for plugins missing one
            try {
                val getNamespaceMethod = androidExt.javaClass.getMethod("getNamespace")
                val currentNamespace = getNamespaceMethod.invoke(androidExt)
                if (currentNamespace == null) {
                    val setNamespaceMethod = androidExt.javaClass.getMethod("setNamespace", String::class.java)
                    val fallback = if (project.group.toString().isNotEmpty()) {
                        project.group.toString().replace("-", "_")
                    } else {
                        "com.atex.plugins.${project.name.replace("-", "_")}"
                    }
                    setNamespaceMethod.invoke(androidExt, fallback)
                }
            } catch (_: Exception) {}

            // Force compileOptions sourceCompatibility & targetCompatibility to Java 17
            try {
                val getCompileOptionsMethod = androidExt.javaClass.getMethod("getCompileOptions")
                val compileOptions = getCompileOptionsMethod.invoke(androidExt)
                if (compileOptions != null) {
                    val setSource = compileOptions.javaClass.getMethod("setSourceCompatibility", JavaVersion::class.java)
                    val setTarget = compileOptions.javaClass.getMethod("setTargetCompatibility", JavaVersion::class.java)
                    setSource.invoke(compileOptions, JavaVersion.VERSION_17)
                    setTarget.invoke(compileOptions, JavaVersion.VERSION_17)
                }
            } catch (_: Exception) {}
        }
    }

    // Guard with state.executed and register before evaluationDependsOn(":app")
    if (project.state.executed) {
        configureAndroid()
    } else {
        project.afterEvaluate {
            configureAndroid()
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
