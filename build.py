#!/usr/bin/env python3
"""Build a Paper Docker image locally.

Usage: python build.py <MC_VERSION>
"""

import json
import subprocess
import sys
import urllib.request
import zipfile
from pathlib import Path


DOCKER_TAG_BASE = "cr.pandacube.fr/paper"
URL_BASE = "https://fill.papermc.io/v3/projects/paper"
WORKSPACE = Path(__file__).resolve().parent
LIBRARIES_TO_INCLUDE_IN_POM = [
    ("io.netty", "netty-buffer")
]


def run_command(*command: str, capture_output: bool = False) -> str:
    """Run a command and return its output when requested."""
    result = subprocess.run(command, check=True, cwd=WORKSPACE, text=True,
        stdout=subprocess.PIPE if capture_output else sys.stdout,
        stderr=sys.stderr
    )
    return result.stdout.strip() if capture_output else ""



app_git_commit = run_command("git", "rev-parse", "--short", "HEAD", capture_output=True)
USER_AGENT = f"PaperDockerBuilder/{app_git_commit} (https://github.com/PandacubeFr/PaperDockerBuilder)"


def download(url: str, destination: Path) -> None:
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request) as response:
        if response.status != 200:
            raise RuntimeError(f"Failed to download {url}: HTTP {response.status}")
        with destination.open("wb") as output:
            while chunk := response.read(1024 * 1024 * 16):
                output.write(chunk)
                print(f"\rDownloaded {output.tell()} bytes", end="", flush=True)
    print()

def getURL(url: str) -> str:
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request) as response:
        if response.status != 200:
            raise RuntimeError(f"Failed to get {url}: HTTP {response.status}")
        return response.read().decode(response.headers.get_content_charset() or "utf-8")


def get_file_content_in_zip(zip_path: Path, file_name: str) -> str:
    """Extract the content of a file inside a zip archive."""
    with zipfile.ZipFile(zip_path) as jar:
        return jar.read(file_name).decode("utf-8")

class Library:
    def __init__(self, group: str, artifact: str, version: str, path: str):
        self.group = group
        self.artifact = artifact
        self.version = version
        self.path = path

    @staticmethod
    def from_string(library_line: str) -> Library:
        lib_params = library_line.split()
        parts = lib_params[1].split(":", 2)
        if len(parts) != 3:
            raise ValueError(f"Invalid library string format: {library_line} {len(parts)}")
        return Library(parts[0], parts[1], parts[2], lib_params[2])

    @staticmethod
    def list_from_string(libraries_list_content: str) -> list[Library]:
        return [Library.from_string(line) for line in libraries_list_content.splitlines()]

    @staticmethod
    def find_library(libraries: list[Library], group: str, artifact: str) -> Library | None:
        for library in libraries:
            if library.group == group and library.artifact == artifact:
                return library
        return None

def generate_pom_xml(group_id: str, artifact_id: str, version: str, dependencies: list[Library]) -> str:
    dependencies_xml = "".join(
        f"""
        <dependency>
            <groupId>{dep.group}</groupId>
            <artifactId>{dep.artifact}</artifactId>
            <version>{dep.version}</version>
        </dependency>
        """
        for dep in dependencies
    )

    return f"""
<project xmlns="http://maven.apache.org/POM/4.0.0">
    <modelVersion>4.0.0</modelVersion>
    <groupId>{group_id}</groupId>
    <artifactId>{artifact_id}</artifactId>
    <version>{version}</version>
    <dependencies>
{dependencies_xml}
    </dependencies>
</project>
"""



def main() -> int:
    if len(sys.argv) != 2:
        print(f"Usage: {Path(sys.argv[0]).name} <MC_VERSION>")
        print(f"Example: {Path(sys.argv[0]).name} 1.20.1")
        return 1

    mc_version = sys.argv[1]

    version_url = f"{URL_BASE}/versions/{mc_version}"
    build_url = f"{version_url}/builds/latest"




    print("=== Getting build data ===")
    version_infos = json.loads(getURL(version_url))
    build_infos = json.loads(getURL(build_url))

    app_build = build_infos["id"]
    download_url = build_infos["downloads"]["server:default"]["url"]
    app_filename = f"Paper-{mc_version}-{app_build}.jar"
    app_path = WORKSPACE / app_filename

    jdk_version = str(version_infos["version"]["java"]["version"]["minimum"])

    with (WORKSPACE / "jdk_versions.json").open() as jdk_versions_file:
        jdk_tag = json.load(jdk_versions_file).get(jdk_version)

    if not jdk_tag:
        print(f"Error: JDK version {jdk_version} is not listed in jdk_versions.json.", file=sys.stderr)
        print(
            f"Please update jdk_versions.json with a Docker base image for JDK {jdk_version}.",
            file=sys.stderr,
        )
        return 1

    docker_tag = f"{DOCKER_TAG_BASE}:{mc_version}-{app_build}"
    docker_tag_version = f"{DOCKER_TAG_BASE}:{mc_version}"

    print(f"Paper version {mc_version} build #{app_build}")




    print("\n=== Downloading jar ===")
    download(download_url, app_path)
    print(f"Downloaded: {app_filename}")



    
    print(f"\n=== Extracting libraries info from Paper jar ===")
    libraries_str = get_file_content_in_zip(app_path, "META-INF/libraries.list")
    libraries = Library.list_from_string(libraries_str)

    api_lib = Library.find_library(libraries, "io.papermc.paper", "paper-api")
    if not api_lib:
        raise RuntimeError("Unable to find Paper API library in the extracted libraries.")
    print(f"\nPaper API Version is: {api_lib.version}")


    sever_libs_to_include_in_pom: list[Library] = [lib
                                for l in LIBRARIES_TO_INCLUDE_IN_POM
                                if (lib := Library.find_library(libraries, l[0], l[1]))]
    for lib in sever_libs_to_include_in_pom:
        print(f"Library data {lib.group}:{lib.artifact}:{lib.version}.")




    print("\n=== Building Docker image ===")
    print(f"Using base image: {jdk_tag} (for JDK {jdk_version})")
    run_command("docker", "build", "-t", docker_tag,
        "--build-arg", f"RUNNABLE_SERVER_JAR={app_filename}",
        "--build-arg", f"JDK_TAG={jdk_tag}",
        "."
    )
    run_command("docker", "tag", docker_tag, docker_tag_version)




    print("=== Extracting Paper patched jar for local mvn install ===")
    container_id = run_command("docker", "create", docker_tag, capture_output=True)
    paper_server_filename = f"paper-server-{api_lib.version}.jar"
    try:
        run_command(
            "docker", "cp",
            f"{container_id}:/data/bundle/versions/{mc_version}/paper-{mc_version}.jar",
            paper_server_filename,
        )
    finally:
        run_command("docker", "rm", container_id)


    print("\n=== Generating POM file for Paper patched jar ===")
    pom_content = generate_pom_xml(
        group_id="io.papermc.paper",
        artifact_id="paper-server",
        version=api_lib.version,
        dependencies=sever_libs_to_include_in_pom
    )

    pom_name = f"generated_pom-{api_lib.version}.xml"

    with open(pom_name, "w") as f:
        f.write(pom_content)

    print("\n=== Installing Paper patched jar on local Maven repository ===")

    run_command("mvn", "install:install-file", f"-Dfile=./{paper_server_filename}", f"-DpomFile=./{pom_name}")

    print("\nDocker images built successfully:")
    print(f"  - {docker_tag}")
    print(f"  - {docker_tag_version}")
    print("\nPaper patched jar installed successfully on local Maven repository:")
    print(f"  - io.papermc.paper:paper-server:{api_lib.version}")

    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        raise SystemExit(1) from e
