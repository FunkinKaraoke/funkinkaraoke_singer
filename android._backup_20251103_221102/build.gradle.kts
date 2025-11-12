// android/build.gradle.kts (top-level)

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}