#!/usr/bin/env bash
#
# Re-vendor upstream Apache Jackrabbit WebDAV sources and re-apply the
# Jakarta EE 10 transform.
#
# Invoked from .github/workflows/bump-on-dependabot.yml after Dependabot
# opens a PR bumping the upstream.jackrabbit.version property in pom.xml.
# Reads the new upstream version straight from the pom property, downloads
# the matching sources.jar from Maven Central, replaces src/main/{java,
# resources}, runs OpenRewrite, and updates the project version. Caller is
# responsible for committing and pushing.
#
# Idempotent: if the project version already matches the upstream property
# (i.e. nothing left to bump), exits 0 without modifying any files.

set -euo pipefail

UPSTREAM_VERSION="$(mvn -q -B -ntp help:evaluate -Dexpression=upstream.jackrabbit.version -DforceStdout)"
CURRENT_PROJECT_VERSION="$(mvn -q -B -ntp help:evaluate -Dexpression=project.version -DforceStdout)"
EXPECTED_PROJECT_VERSION="${UPSTREAM_VERSION}-jakarta-ee10"

echo "Upstream version from pom.xml property: ${UPSTREAM_VERSION}"
echo "Current project.version:                ${CURRENT_PROJECT_VERSION}"
echo "Target  project.version:                ${EXPECTED_PROJECT_VERSION}"

if [[ "${CURRENT_PROJECT_VERSION}" == "${EXPECTED_PROJECT_VERSION}" ]]; then
    echo "Project version already matches upstream property — nothing to do."
    exit 0
fi

URL="https://repo1.maven.org/maven2/org/apache/jackrabbit/jackrabbit-webdav/${UPSTREAM_VERSION}/jackrabbit-webdav-${UPSTREAM_VERSION}-sources.jar"
echo "Downloading ${URL}"
curl -fsSL -o sources.jar.new "${URL}"
mv sources.jar.new sources.jar

workspace="$PWD"
rm -rf src/main/java src/main/resources
mkdir -p src/main/java src/main/resources

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
unzip -q sources.jar -d "$tmp"
rm -rf "$tmp/META-INF"

# .java sources → src/main/java; everything else (e.g. .properties) →
# src/main/resources. Upstream sources.jar contains both intermixed.
(cd "$tmp" && find . -type f -name '*.java' | while read -r f; do
     dest="$workspace/src/main/java/${f#./}"
     mkdir -p "$(dirname "$dest")"
     cp "$f" "$dest"
 done)
(cd "$tmp" && find . -type f ! -name '*.java' | while read -r f; do
     dest="$workspace/src/main/resources/${f#./}"
     mkdir -p "$(dirname "$dest")"
     cp "$f" "$dest"
 done)

echo "Re-applying Jakarta EE 10 transform via OpenRewrite"
mvn -B -ntp rewrite:run

echo "Setting project version to ${EXPECTED_PROJECT_VERSION}"
mvn -B -ntp versions:set -DnewVersion="${EXPECTED_PROJECT_VERSION}" -DgenerateBackupPoms=false

echo "Bump complete: jackrabbit-webdav ${UPSTREAM_VERSION} → ${EXPECTED_PROJECT_VERSION}"
