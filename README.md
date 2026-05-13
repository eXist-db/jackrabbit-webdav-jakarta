# jackrabbit-webdav-jakarta

A thin fork of [Apache Jackrabbit WebDAV](https://jackrabbit.apache.org/) with the
`javax.servlet` → `jakarta.servlet` namespace transform applied so [eXist-db 7.0](https://github.com/eXist-db/exist)
(Jetty 12, Jakarta Servlet 6.0) can link against it.

This artifact exists only until Apache publishes a Jakarta-Servlet-native release of
`jackrabbit-webdav` upstream, at which point this repo will be archived and the
eXist-db dependency redirected to the upstream coordinate.

## Coordinates

```xml
<dependency>
    <groupId>org.exist-db.thirdparty.org.apache.jackrabbit</groupId>
    <artifactId>jackrabbit-webdav</artifactId>
    <version>2.22.3-jakarta-ee10</version>
</dependency>
```

Published to GitHub Packages: <https://maven.pkg.github.com/eXist-db/jackrabbit-webdav-jakarta>

## Versioning

`<upstream-version>-jakarta-ee10`

- `2.22.3-jakarta-ee10` → Apache Jackrabbit `2.22.3` + this repo's Jakarta EE 10 transform
- Snapshots use `<upstream>-jakarta-ee10-SNAPSHOT`

The version string makes the upstream provenance auditable at a glance — both the
upstream tag and the Jakarta profile are encoded in the version, with no hidden
metadata in classifiers or qualifiers.

## How the transform works

Upstream Apache Jackrabbit sources are vendored at `src/main/java/`, pre-transformed
to `jakarta.servlet.*`. The canonical pre-transform source archive is the
`sources.jar` at the repo root (extracted from Maven Central). The transform is
applied via the [OpenRewrite Maven plugin](https://docs.openrewrite.org/) using
the `org.openrewrite.java.migrate.jakarta.JakartaEE10` recipe — but the rewrite
runs **at upstream-bump time**, not at every build:

```sh
# After extracting a new sources.jar over src/main/java/:
mvn rewrite:run
```

The transformed result is committed to the repo, so day-to-day builds are plain
`mvn compile` against already-jakarta source. There are no manual patches, no
`sed` scripts, and no hand-edited source files — the only diff against upstream
is whatever OpenRewrite produces.

## How upstream tracking works

Dependabot handles the polling. A tracker-only `<dependencyManagement>` entry
in `pom.xml` declares `org.apache.jackrabbit:jackrabbit-webdav` at
`${upstream.jackrabbit.version}`, with no corresponding `<dependencies>` entry —
so the coordinate stays off the compile classpath but is visible to Dependabot's
Maven manifest scan ([`.github/dependabot.yml`](.github/dependabot.yml)).

When Apache cuts a new `jackrabbit-webdav` release, Dependabot opens a PR
labelled `upstream-bump` that bumps the `upstream.jackrabbit.version` property.
That PR fires [`bump-on-dependabot.yml`](.github/workflows/bump-on-dependabot.yml),
which does the work Dependabot can't:

1. Reads the new upstream version from the bumped property
2. Downloads the matching `*-sources.jar` from Maven Central, replacing the
   `sources.jar` at the repo root
3. Re-extracts source into `src/main/java/` (`.java` files) and
   `src/main/resources/` (everything else)
4. Runs `mvn rewrite:run` to re-apply the Jakarta EE 10 transform
5. Bumps the project `<version>` to `<new-upstream>-jakarta-ee10`
6. Commits and pushes back onto the Dependabot branch

The smoke test ([`ci.yml`](.github/workflows/ci.yml)) then re-runs against the
follow-up commit and gates merge: if the new upstream version still cleanly
transforms and links against Jakarta Servlet 6.0, the bump is safe to merge.

## How to cut a release

1. Land all bump / fix PRs on `main`
2. Tag the release commit:
   ```sh
   git tag v2.22.3-jakarta-ee10
   git push origin v2.22.3-jakarta-ee10
   ```
3. The publish workflow ([`publish.yml`](.github/workflows/publish.yml)) fires on
   `v*` tag push and deploys to GitHub Packages
4. Confirm the artifact resolves at
   `https://maven.pkg.github.com/eXist-db/jackrabbit-webdav-jakarta`

`workflow_dispatch` is also wired up if you need to publish a SNAPSHOT manually.

## Consuming from a local Maven build

GitHub Packages requires authentication for read access. Add to `~/.m2/settings.xml`:

```xml
<servers>
  <server>
    <id>github-jackrabbit-webdav-jakarta</id>
    <username>YOUR_GITHUB_USERNAME</username>
    <password>YOUR_PAT_WITH_read:packages</password>
  </server>
</servers>
```

The same PAT works across every `github-*` server id the eXist-db org publishes
(`github`, `github-xqts-runner`, and this one) — one PAT, multiple `<server>`
blocks. The repository declaration lives in `exist-parent/pom.xml` in
[eXist-db/exist](https://github.com/eXist-db/exist).

## License / attribution

Licensed under the [Apache License, Version 2.0](https://www.apache.org/licenses/LICENSE-2.0),
inherited from upstream. This repository is a derivative work of
[apache/jackrabbit](https://github.com/apache/jackrabbit); all credit for the
WebDAV implementation belongs to the Apache Jackrabbit project. The only
modifications applied here are the OpenRewrite namespace transforms required for
Jakarta EE 10 compatibility.
