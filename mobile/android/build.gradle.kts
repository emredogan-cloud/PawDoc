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

// ── Build fix (Device Validation, 2026-06-04) ───────────────────────────────
// sentry_flutter 8.14.2 pins Kotlin languageVersion/apiVersion 1.6, which the
// Kotlin 2.2.20 compiler bundled with Flutter 3.41.9 no longer supports (min 1.8),
// failing `:sentry_flutter:compileDebugKotlin` with "Language version 1.6 is no
// longer supported". Raise ONLY that module to 1.8 (the compiler minimum) —
// surgical, no dependency-version change, zero blast radius on other plugins
// (some of which rely on 1.9+ language features, so a blanket downgrade is unsafe).
// Permanent fix: upgrade sentry_flutter to a Kotlin-2.x-compatible release.
subprojects {
    if (project.name == "sentry_flutter") {
        tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
            compilerOptions {
                languageVersion.set(org.jetbrains.kotlin.gradle.dsl.KotlinVersion.KOTLIN_1_8)
                apiVersion.set(org.jetbrains.kotlin.gradle.dsl.KotlinVersion.KOTLIN_1_8)
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
