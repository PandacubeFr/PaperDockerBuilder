/*
Required plugins in Jenkins:
- Pipeline Utility Steps
- Docker Pipeline
*/

def app_version
def app_build
def url_download
def app_filename
def docker_tag
def docker_tag_version
def api_version
def patched_jar_filename
def version_infos
def build_infos
def libraries_to_include_in_pom = [
    ["io.netty", "netty-buffer"]
]
def server_libs_to_include_in_pom

pipeline {
    agent any

    parameters {
        string(name: 'MC_VERSION', description: 'The Minecraft version to build.')
    }

    environment {
        APP_GIT_COMMIT = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
        USER_AGENT = "PaperDockerBuilder/${APP_GIT_COMMIT} (https://github.com/PandacubeFr/PaperDockerBuilder)"

        URL_BASE = 'https://fill.papermc.io/v3/projects/paper'
        URL_VERSION_INFOS = "${URL_BASE}/versions/${params.MC_VERSION}"
        URL_BUILD_INFOS = "${URL_BASE}/versions/${params.MC_VERSION}/builds/latest"

        DOCKER_TAG_BASE = 'cr.pandacube.fr/paper'
        DOCKER_REGISTRY_URL = 'https://cr.pandacube.fr'
        DOCKER_REGISTRY_CREDENTIALS = 'cr-pandacube-credentials'
    }

    stages {

        stage('Get build data') {
            steps {
                script {
                    version_infos = readJSON text: sh(script:  "curl -A '$USER_AGENT' -L -s '$URL_VERSION_INFOS'", returnStdout: true).trim()
                    build_infos = readJSON text: sh(script:  "curl -A '$USER_AGENT' -L -s '$URL_BUILD_INFOS'", returnStdout: true).trim()
                }
                script {
                    app_version = params.MC_VERSION
                    app_build = build_infos.id
                    def app_channel = build_infos.channel
                    
                    url_download = build_infos.downloads['server:default'].url
                    app_filename = "Paper-${app_version}-${app_build}.jar"

                    docker_tag = "${DOCKER_TAG_BASE}:${app_version}-${app_build}"
                    docker_tag_version = "${DOCKER_TAG_BASE}:${app_version}"

                    echo "Paper version ${app_version} build #${app_build}"

                    if (app_channel != 'STABLE' && app_channel != 'RECOMMENDED') {
                        unstable("Build #${app_build} of Paper ${app_version} has status '${app_channel}'.")
                    }

                }

            }
        }

        stage('Download jar') {
            steps {
                sh "curl -A '$USER_AGENT' -L -o '$app_filename' '$url_download'"
            }
            post {
                success {
                    archiveArtifacts artifacts: 'Paper-*.jar', fingerprint: true
                }
                unstable {
                    archiveArtifacts artifacts: 'Paper-*.jar', fingerprint: true
                }
            }
        }

        stage('Build Docker image') {
            steps {
                script {
                    def jdk_versions = readJSON file: 'jdk_versions.json'
                    def jdk_version = version_infos['version']['java']['version']['minimum'].toString() // Get the minimum supported Java version

                    if (!jdk_versions.containsKey(jdk_version)) {
                        error("JDK version ${jdk_version} is not listed in jdk_versions.json. Please update the file with the appropriate Docker image for JDK ${jdk_version}.")
                    }
                    else {
                        def jdk_tag = jdk_versions[jdk_version]
                        print("Using base image ${jdk_tag} to build the Paper Docker image.")
                        docker.build(docker_tag, "--build-arg RUNNABLE_SERVER_JAR=${app_filename} --build-arg JDK_TAG=${jdk_tag} .")
                    }
                }
            }
        }

        stage('Parallel stages') {
            parallel {
                stage('Push Docker image') {
                    steps {
                        sh "docker tag ${docker_tag} ${docker_tag_version}"
                        script {
                            docker.withRegistry(DOCKER_REGISTRY_URL, DOCKER_REGISTRY_CREDENTIALS) {
                                docker.image(docker_tag).push()
                                docker.image(docker_tag_version).push()
                            }
                        }
                    }
                }

                stage('Patched Jar') {
                    stages {

                        stage('Extract API and libraries versions') {
                            steps {
                                script {
                                    def libraries_list_content = sh(script: "unzip -p ${app_filename} META-INF/libraries.list", returnStdout: true).trim()
                                    def libraries = Library.list_from_string(libraries_list_content)
                                    def paper_api_library = Library.find_library(libraries, "io.papermc.paper", "paper-api")
                                    
                                    api_version = paper_api_library?.version ?: ""
                                    patched_jar_filename = "paper-server-${api_version}.jar"
                                    echo "Paper API Version is: ${api_version}"

                                    server_libs_to_include_in_pom = libraries_to_include_in_pom.collect { lib ->
                                        def found_lib = Library.find_library(libraries, lib[0], lib[1])
                                        if (found_lib) {
                                            return found_lib
                                        } else {
                                            error("Required library ${lib[0]}:${lib[1]} not found in the libraries.list.")
                                        }
                                    }
                                }
                            }
                        }
                        stage('Extract and install Patched jar in Maven local repository') {
                            tools {
                                maven 'Maven 3.9.5' 
                            }
                            steps {
                                script {
                                    def tempContainerId = sh(script: "docker create ${docker_tag}", returnStdout: true).trim()
                                    sh "docker cp ${tempContainerId}:/data/bundle/versions/${app_version}/paper-${app_version}.jar ./${patched_jar_filename}"
                                    sh "docker rm ${tempContainerId}"
                                }
                                script {
                                    def pom_content = generate_pom_xml("io.papermc.paper", "paper-server", api_version, server_libs_to_include_in_pom)
                                    def pom_name = "generated_pom-${api_version}.xml"
                                    writeFile file: pom_name, text: pom_content
                                    sh "mvn install:install-file -Dfile=./${patched_jar_filename} -DpomFile=./${pom_name}"
                                }
                            }
                        }
                    }
                    post {
                        success {
                            archiveArtifacts artifacts: 'paper-server-*.jar', fingerprint: true
                        }
                        unstable {
                            archiveArtifacts artifacts: 'paper-server-*.jar', fingerprint: true
                        }
                    }
                }
            }
        }

        
        
    }

    post {
        cleanup {
            cleanWs()
            sh "docker image rm ${docker_tag} ${docker_tag_version}"
        }
    }
}


class Library {
    String groupId
    String artifactId
    String version

    Library(String groupId, String artifactId, String version) {
        this.groupId = groupId
        this.artifactId = artifactId
        this.version = version
    }

    static Library from_string(String library_line) {
        def lib_params = library_line.split()
        def parts = lib_params[1].split(":", 2)
        if (parts.length != 3) {
            throw new IllegalArgumentException("Invalid library string format: ${library_line} ${parts.length}")
        }
        return new Library(parts[0], parts[1], parts[2])
    }

    static List<Library> list_from_string(String libraries_list_content) {
        def libraries = []
        libraries_list_content.eachLine { line ->
            if (line.trim()) {
                libraries.add(Library.from_string(line))
            }
        }
        return libraries
    }

    static Library find_library(List<Library> libraries, String groupId, String artifactId) {
        return libraries.find { it.groupId == groupId && it.artifactId == artifactId }
    }
}


def generate_pom_xml(groupId, artifactId, version, List<Library> dependencies) {
    def dependencies_xml = dependencies.collect { lib ->
        """
        <dependency>
            <groupId>${lib.groupId}</groupId>
            <artifactId>${lib.artifactId}</artifactId>
            <version>${lib.version}</version>
        </dependency>
        """
    }.join("")

    return """
<project xmlns="http://maven.apache.org/POM/4.0.0">
    <modelVersion>4.0.0</modelVersion>
    <groupId>${groupId}</groupId>
    <artifactId>${artifactId}</artifactId>
    <version>${version}</version>
    <dependencies>
        ${dependencies_xml}
    </dependencies>
</project>"""
}