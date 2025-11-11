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
def docker_tag_latest

pipeline {
    agent any

    parameters {
        string(name: 'MC_VERSION', description: 'The Minecraft version to build.')
    }

    environment {
        APP_GIT_COMMIT = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
        USER_AGENT = "PaperDockerBuilder/${APP_GIT_COMMIT} (https://github.com/PandacubeFr/PaperDockerBuilder)"

        URL_BASE = 'https://fill.papermc.io/v3/projects/paper'
        URL_BUILD_INFOS = "${URL_BASE}/versions/${params.MC_VERSION}/builds/latest"

        DOCKER_TAG_BASE = 'cr.pandacube.fr/paper'
        DOCKER_REGISTRY_URL = 'https://cr.pandacube.fr'
        DOCKER_REGISTRY_CREDENTIALS = 'cr-pandacube-credentials'
    }

    stages {

        stage('Get build data') {
            steps {
                sh "curl -A '$USER_AGENT' -L -s '$URL_BUILD_INFOS' -o build_infos.json"
                script {
                    def build_infos = readJSON file: 'build_infos.json'
                    
                    app_version = params.MC_VERSION
                    app_build = build_infos.id
                    app_channel = build_infos.channel
                    url_download = build_infos.downloads['server:default'].url
                    app_filename = "Paper-${app_version}-${app_build}.jar"

                    docker_tag = "${DOCKER_TAG_BASE}:${app_version}-${app_build}"
                    docker_tag_version = "${DOCKER_TAG_BASE}:${app_version}"
                }
                echo "Paper version ${app_version} build #${app_build}"

                script {
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
            }
        }

        stage('Build Docker image') {
            steps {
                script {
                    docker.build(docker_tag, "--build-arg RUNNABLE_SERVER_JAR=$app_filename .")
                }
                sh "docker tag ${docker_tag} ${docker_tag_version}"
            }
        }

        stage('Push Docker image') {
            steps {
                script {
                    docker.withRegistry(DOCKER_REGISTRY_URL, DOCKER_REGISTRY_CREDENTIALS) {
                        docker.image(docker_tag).push()
                        docker.image(docker_tag_version).push()
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