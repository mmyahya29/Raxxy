allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Custom build dir relocation (optional, you can remove if not needed)
val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

plugins {
    // Google services Gradle plugin
    id("com.google.gms.google-services") version "4.4.3" apply false
    id("com.android.application") version "8.11.1" apply false
    id("org.jetbrains.kotlin.android") version "2.2.0" apply false
}
