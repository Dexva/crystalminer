plugins {
    java
    application
}

group = "crystalminer"
version = "0.1.0"

repositories {
    mavenCentral()
}

dependencies {
    implementation("net.minestom:minestom:2026.10.07-26.2")
    implementation("com.anthropic:anthropic-java:2.75.0")
    implementation("org.yaml:snakeyaml:2.7")
    testImplementation("net.minestom:testing:2026.10.07-26.2")
    testImplementation(platform("org.junit:junit-bom:6.1.3"))
    testImplementation("org.junit.jupiter:junit-jupiter")
    testRuntimeOnly("org.junit.platform:junit-platform-launcher")
}

java {
    toolchain.languageVersion = JavaLanguageVersion.of(25)
}

application {
    mainClass = "crystalminer.server.CrystalMinerServer"
}

tasks.test {
    useJUnitPlatform()
    // Lets Minestom's test environment create players outside virtual threads.
    systemProperty("minestom.inside-test", "true")
}

tasks.withType<JavaCompile> {
    options.compilerArgs.add("-Xlint:deprecation")
}
