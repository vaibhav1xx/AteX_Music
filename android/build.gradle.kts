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

subprojects {
    project.evaluationDependsOn(":app")
}

// AGP 8+ Compatibility: Automatically inject a fallback namespace for any third-party
// Flutter plugin missing one (e.g., on_audio_query_android) to prevent build failures.
subprojects {
    plugins.whenPluginAdded {
        if (this.javaClass.name.contains("com.android.build.gradle")) {
            afterEvaluate {
                val androidExt = project.extensions.findByName("android")
                if (androidExt != null) {
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
                }
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
