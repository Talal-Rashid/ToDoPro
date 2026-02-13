allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
    
    // FORCE ALL PLUGINS TO SDK 36
    afterEvaluate {
        if (project.hasProperty("android")) {
            // Configure both application and library Android extensions
            try {
                project.extensions.configure<com.android.build.gradle.internal.dsl.BaseAppModuleExtension> {
                    compileSdk = 36

                    compileOptions {
                        isCoreLibraryDesugaringEnabled = true
                        sourceCompatibility = JavaVersion.VERSION_17
                        targetCompatibility = JavaVersion.VERSION_17
                    }
                }
            } catch (_: Exception) {}

            // For library modules do not enable coreLibraryDesugaring (requires multidex on apps)
            try {
                project.extensions.configure<com.android.build.gradle.LibraryExtension> {
                    compileSdk = 36
                    // leave compileOptions to module defaults; app module controls desugaring
                }
            } catch (_: Exception) {}

            // (Intentionally left blank) Kotlin JVM target is handled by individual modules/toolchains

            // Add core library desugaring dependency for subprojects that need it
            try {
                project.dependencies.add("coreLibraryDesugaring", "com.android.tools:desugar_jdk_libs:2.1.4")
            } catch (_: Exception) {}
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}