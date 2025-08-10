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
        URL_BASE = 'https://api.papermc.io/v2/projects/paper'
        URL_VERSION_INFOS = "${URL_BASE}/versions/${params.MC_VERSION}"

        DOCKER_TAG_BASE = 'cr.pandacube.fr/paper'
        DOCKER_REGISTRY_URL = 'https://cr.pandacube.fr'
        DOCKER_REGISTRY_CREDENTIALS = 'cr-pandacube-credentials'
    }

    stages {

        stage('Get build data') {
            steps {
                sh "curl -L -s '$URL_VERSION_INFOS' -o version_infos.json"
                script {
                    def version_infos = readJSON file: 'version_infos.json'
                    
                    app_version = params.MC_VERSION
                    app_build = version_infos.builds[-1]
                    url_download = "${URL_VERSION_INFOS}/builds/${app_build}/downloads/paper-${app_version}-${app_build}.jar"
                    app_filename = "Paper-${MC_VERSION}-${app_build}.jar"

                    docker_tag = "${DOCKER_TAG_BASE}:${app_version}-${app_build}"
                    docker_tag_version = "${DOCKER_TAG_BASE}:${app_version}"
                }
                echo "Paper version ${app_version} build #${app_build}"
            }
        }

        stage('Download jar') {
            steps {
                sh "curl -L -o '$app_filename' '$url_download'"
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