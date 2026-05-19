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

// Global Patcher for AGP 8.0+ Compatibility (Namespace & Manifest issues)
subprojects {
    val configureAndroid = {
        if (project.hasProperty("android")) {
            val android = project.extensions.getByName("android")
            
            try {
                // 1. Resolve "Namespace vs Manifest Package" clash
                val manifestFile = project.file("src/main/AndroidManifest.xml")
                if (manifestFile.exists()) {
                    var manifestContent = manifestFile.readText()
                    val packagePattern = Regex("""package="([^"]+)"""")
                    val match = packagePattern.find(manifestContent)
                    
                    val setNamespace = android.javaClass.getMethod("setNamespace", String::class.java)
                    val getNamespace = android.javaClass.getMethod("getNamespace")
                    
                    if (getNamespace.invoke(android) == null) {
                        // Use the existing package name as the namespace
                        val pkgName = match?.groupValues?.get(1) ?: "com.example.${project.name.replace("-", "_")}"
                        setNamespace.invoke(android, pkgName)
                        
                        // AGP 8+ fails if 'package' is in XML while 'namespace' is in Gradle.
                        // We strip the 'package' attribute from the XML content.
                        if (match != null) {
                            val newContent = manifestContent.replace(packagePattern, "")
                            manifestFile.writeText(newContent)
                            println("Patcher: Stripped 'package' from ${project.name} Manifest and set as Namespace: $pkgName")
                        }
                    }
                }
            } catch (e: Exception) {
                // Ignore errors for non-android subprojects
            }

            // 2. Force SDK 36 for all modules (Required for modern AndroidX)
            try {
                val setCompileSdkVersion = android.javaClass.getMethod("setCompileSdkVersion", Int::class.javaPrimitiveType)
                setCompileSdkVersion.invoke(android, 36)
            } catch (e: Exception) {}

            // 3. Force Min SDK 21
            try {
                val defaultConfig = android.javaClass.getMethod("getDefaultConfig").invoke(android)
                val setMinSdkVersion = defaultConfig.javaClass.getMethod("setMinSdkVersion", Any::class.java)
                setMinSdkVersion.invoke(defaultConfig, 21)
            } catch (e: Exception) {}
        }
    }

    if (project.state.executed) {
        configureAndroid()
    } else {
        project.afterEvaluate { configureAndroid() }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
