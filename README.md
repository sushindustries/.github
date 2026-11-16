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

## Prerequisites

- This repo must be public, or private with Actions access set to "Accessible from repositories in the organization"
  (Settings > Actions > General > Access). Otherwise callers cannot use the workflow.
- The caller must grant the four job permissions shown above.

## Pins

The action SHA pins are copied from ruby-api-realm PR #2. Update them together with that repo.
