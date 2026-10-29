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
// firebase_core / firebase_messaging pin compileSdk 34 in their own local-config.gradle,
// but this machine's android-34 platform is missing core-for-system-modules.jar, so AGP
// cannot build the JDK image for it and fails task-dependency resolution with
// ":firebase_core ... Cannot query the value of this provider because it has no value
// available". android-35+ ship that jar, so bump any subproject still on android-34 to 35.
fun bumpCompileSdk34(project: Project) {
    val android = project.extensions.findByName("android") ?: return
    try {
        val current =
            android.javaClass.getMethod("getCompileSdkVersion").invoke(android) as? String
        if (current == "android-34") {
            android.javaClass
                .getMethod("compileSdkVersion", Int::class.javaPrimitiveType)
                .invoke(android, 35)
        }
    } catch (_: Exception) {
        // Extension isn't an AGP one we can adjust; leave it untouched.
    }
}
subprojects {
    if (state.executed) bumpCompileSdk34(project) else afterEvaluate { bumpCompileSdk34(project) }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

