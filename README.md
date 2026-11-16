# sushindustries/.github

Org-wide reusable workflows.

## images.yml

Reusable workflow (`workflow_call`) that builds one or more images, scans each with Trivy
(fails on CRITICAL by default) BEFORE pushing, then pushes to GHCR and attests provenance.
It pushes only on a push to the default branch or a `v*` tag; pull requests build and scan only.

Inputs: `images` (required, JSON array of `{name, context, dockerfile}`), `platforms`
(default `linux/amd64`), `trivy-severity` (default `CRITICAL`), `registry` (default `ghcr.io`),
`image-prefix` (default `ghcr.io/sushindustries`).

Note: the scan build is always `linux/amd64` (a loaded image is single-platform).

### Caller example

```yaml
name: images
on:
  push: {branches: [main], tags: ["v*"]}
  pull_request:
permissions: {}
jobs:
  images:
    uses: sushindustries/.github/.github/workflows/images.yml@main  # TODO pin to a SHA once that repo exists
    permissions: {contents: read, packages: write, id-token: write, attestations: write}
    with:
      images: '[{"name":"<image>","context":".","dockerfile":"Dockerfile"}]'
```

Use the repo's default branch name instead of `main` if it differs.

## nuget-release.yml

Reusable workflow (`workflow_call`) that builds, tests, packs and publishes NuGet packages to GitHub Packages
from a release tag, then creates a GitHub release with the packages attached and generated notes
(from the previous tag with the same prefix). The scripts it runs live in `scripts/nuget-release/` of this repo.

**The version comes from the tag**, never from the project files: it is passed to the build and pack as
`-p:Version` and `-p:MinVerVersionOverride`, and `verify-packages.sh` fails the run if any package file does not
carry it. A `-label` suffix (`v1.2.0-rc.1`) makes the release a prerelease.

### Tag scheme

| Tag | Releases | Built in |
|---|---|---|
| `vX.Y.Z` | the whole repo | the repo root |
| `<family>/vX.Y.Z` | one package family | `<families-root>/<family>` (default `packages/<family>`) |

### Inputs

All inputs are optional.

| Input | Default | Meaning |
|---|---|---|
| `tag` | `''` | Release tag. Empty uses `github.ref_name`; set it for `workflow_dispatch` dry runs. |
| `families-root` | `packages` | Folder with one sub-folder per family. |
| `exclude-families` | `''` | Comma list of families this repo must never release. |
| `pack-target` | `''` | Solution or project to build, test and pack, relative to the release folder. Empty picks the one solution, else the one packable project (fails if ambiguous). |
| `test-command` | `dotnet test -c Release --no-build` | Run in the release folder after the build. Empty skips tests. |
| `require-green-ci` | `false` | Fail unless all check runs on the tagged commit are green (and there is at least one). |
| `ci-ignore` | `^(release\|SonarCloud)` | Regex of check run names that `require-green-ci` ignores: this workflow's own job and checks that are always red or cancelled. |
| `dry-run` | `false` | Build, test, pack and verify, list the packages in the job summary; no push, no release. |
| `node-version` | `''` | Set up Node.js when non-empty. |
| `pnpm-version` | `''` | Set up pnpm when non-empty. |
| `runs-on` | `ubuntu-latest` | Runner label. |
| `feed` | `https://nuget.pkg.github.com/sushindustries/index.json` | NuGet feed the packages are pushed to. |
| `tooling-ref` | `main` | Ref of `sushindustries/.github` whose scripts are used. |

The .NET SDK comes from `global.json` in the release folder, else the one in the repo root.

### Caller example: single-package repo

```yaml
name: release
on:
  push: {tags: ["v*"]}
  workflow_dispatch:
    inputs:
      tag: {description: "Tag to dry-run, e.g. v1.2.3", required: true}
permissions: {}
jobs:
  release:
    uses: sushindustries/.github/.github/workflows/nuget-release.yml@main  # pin to a SHA once that repo exists
    permissions: {contents: write, packages: write, checks: read}
    with:
      tag: ${{ inputs.tag }}
      dry-run: ${{ github.event_name == 'workflow_dispatch' }}
      require-green-ci: true
```

### Caller example: multi-family repo

```yaml
name: release
on:
  push: {tags: ["*/v*"]}
permissions: {}
jobs:
  release:
    uses: sushindustries/.github/.github/workflows/nuget-release.yml@main  # pin to a SHA once that repo exists
    permissions: {contents: write, packages: write, checks: read}
    with:
      families-root: packages
      exclude-families: legacy,old-copy
      require-green-ci: true
```

Pushing `orders/v2.1.0` builds and releases `packages/orders` only.

### Required caller permissions

`contents: write` (release), `packages: write` (push), `checks: read` (`require-green-ci`). The caller job must grant
all three, as in the examples. The push and the release use the job's `github.token`; no secret is needed.

### Restoring from the feed

Consumers add the feed to `nuget.config` and supply credentials from environment variables:

```xml
<configuration>
  <packageSources>
    <add key="sushindustries" value="https://nuget.pkg.github.com/sushindustries/index.json" />
  </packageSources>
  <packageSourceCredentials>
    <sushindustries>
      <add key="Username" value="%NUGET_USER%" />
      <add key="ClearTextPassword" value="%NUGET_TOKEN%" />
    </sushindustries>
  </packageSourceCredentials>
</configuration>
```

`NUGET_USER` is a GitHub user name and `NUGET_TOKEN` a token with `read:packages` (in Actions, `github.actor`
and `github.token` with `packages: read`).

## Prerequisites

- This repo must be public, or private with Actions access set to "Accessible from repositories in the organization"
  (Settings > Actions > General > Access). Otherwise callers cannot use the workflow.
- The caller must grant the job permissions shown in each caller example.

## Pins

The action SHA pins are copied from ruby-api-realm PR #2. Update them together with that repo.
