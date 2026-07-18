---
name: git-release
description: Standardized release workflow — changelog validation, tagging, and platform release creation.
---

# Git Release

## Table of Contents

- [Overview](#overview)
- [Changelog Format](#changelog-format)
- [Version Inference](#version-inference)
- [Phase 1 — Release PR](#phase-1-release-pr)
- [Phase 2 — Tag and Publish](#phase-2-tag-and-publish)
  - [Create signed tag](#create-signed-tag)
  - [Push tag only](#push-tag-only)
  - [Build artifacts (if applicable)](#build-artifacts-if-applicable)
- [Phase 3 — Create Platform Release](#phase-3-create-platform-release)
  - [CI available (GitHub Actions / GitLab CI)](#ci-available-github-actions-gitlab-ci)
  - [No CI / CI unavailable](#no-ci-ci-unavailable)
- [Capability-Based Enhancements](#capability-based-enhancements)
- [Checklist](#checklist)
- [Quick Reference — Tool Routing](#quick-reference-tool-routing)

## Overview

Releases follow a two-phase flow: a **release PR** (branch → PR → merge) that updates the changelog and version files, then a **tag + publish** step from the default branch.

The `changelog-guard` hook blocks `git tag vX.Y.Z` unless a matching version heading exists in `CHANGELOG.md`. The `make changelog` target validates format at every `make qa` run.

---

## Changelog Format

`CHANGELOG.md` MUST follow [Keep a Changelog 1.1.0](https://keepachangelog.com/en/1.1.0/) with [SemVer](https://semver.org/spec/v2.0.0.html).

```md
# Changelog

All notable changes to this project will be documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **scope**: description of new capability

## [vX.Y.Z](https://github.com/org/repo/compare/vPREV...vX.Y.Z) - YYYY-MM-DD

### Fixed
- **scope**: description of bug fix
```

Rules:
- `## [Unreleased]` MUST always be present at the top
- Allowed subsection headers: `Added`, `Changed`, `Deprecated`, `Removed`, `Fixed`, `Security`
- Entry format: `- **scope**: description` (imperative, lowercase, no period)
- **Top-level bullets only — no nested/sub-bullets.** Each entry is a single flat `-` line; fold any sub-points into one bullet's description instead of indenting a child list
- Version headings include a compare URL and ISO 8601 date (`YYYY-MM-DD`)
- First release: omit compare URL or link to the tag directly
- Monorepos: scope tags as `plugin-name/vX.Y.Z`

---

## Version Inference

Infer the next version from the `[Unreleased]` categories — always confirm with the user:

| Categories present | Bump |
|--------------------|------|
| `Removed`, `BREAKING CHANGE` marker | Major |
| `Added`, `Changed` | Minor |
| `Fixed`, `Security`, `Deprecated` only | Patch |
| Pre-release candidate | Append `-rc.N` |

---

## Phase 1 — Release PR

**Preconditions before starting:**
- `[Unreleased]` section has at least one entry
- Working tree is clean (`git status --porcelain` is empty)
- `make qa` passes

```sh
git checkout -b release/vX.Y.Z
```

1. Open `CHANGELOG.md`
2. Rename `## [Unreleased]` → `## [vX.Y.Z](compare-url) - YYYY-MM-DD`
   - Compare URL: `https://<host>/<org>/<repo>/compare/vPREV...vX.Y.Z`
   - For first release: `https://<host>/<org>/<repo>/releases/tag/vX.Y.Z`
3. Insert a fresh `## [Unreleased]` section above the new version heading
4. Bump version in any relevant version files (`pyproject.toml`, `Cargo.toml`, `package.json`, `plugin.json`, `gemini-extension.json`, `marketplace.json`)
5. Run `make qa` — zero failures required

```sh
git add CHANGELOG.md <version-files>
git commit -m "chore(release): vX.Y.Z"
```

6. Push and open PR targeting `main` (or `devel` if it exists):
   - Use `mcp__git-ops__create_pr` (preferred) or `gh pr create`
7. Merge PR via `mcp__git-ops__merge_pr` (preferred) or `gh pr merge --squash`
8. Delete release branch

---

## Phase 2 — Tag and Publish

After the release PR is merged:

```sh
git checkout main && git pull --ff-only
```

Verify the merged commit is clean and `CHANGELOG.md` has the `[vX.Y.Z]` heading.

### Create signed tag

```sh
git tag -a vX.Y.Z -m "Release vX.Y.Z"
```

Add `-s` if a GPG or SSH signing key is configured:

```sh
git config user.signingkey && git tag -s vX.Y.Z -m "Release vX.Y.Z"
```

### Push tag only

```sh
git push origin vX.Y.Z
```

Do NOT use `--follow-tags` or push `main` directly.

### Build artifacts (if applicable)

If the project has a `release` make target, run it before creating the platform release:

```sh
[ -f Makefile ] && make release
sha256sum dist/* > dist/checksums-sha256.txt
```

---

## Phase 3 — Create Platform Release

### CI available (GitHub Actions / GitLab CI)

The tag push triggers the release pipeline. Do NOT create the release manually — CI handles artifacts, checksums, and SBOM. Monitor with `gh run list` or `glab ci status`.

### No CI / CI unavailable

Use `mcp__git-ops__create_release` (preferred):

```
mcp__git-ops__create_release(
  tag="vX.Y.Z",
  title="vX.Y.Z",
  notes="<changelog section for this version>",
  draft=false
)
```

Or fall back to platform CLI:

```sh
# GitHub
gh release create vX.Y.Z \
  --title "vX.Y.Z" \
  --notes-file /tmp/release-notes.md \
  dist/*

# GitLab
glab release create vX.Y.Z \
  --name "vX.Y.Z" \
  --notes "$(sed -n '/## \[vX.Y.Z\]/,/^## \[/p' CHANGELOG.md | head -n -1)"

# Attach artifacts to GitLab release via package registry
curl --header "JOB-TOKEN: $CI_JOB_TOKEN" \
  --upload-file dist/artifact.tar.gz \
  "${CI_API_V4_URL}/projects/${CI_PROJECT_ID}/packages/generic/<name>/vX.Y.Z/artifact.tar.gz"
```

**BoschDevCloud personal repos** (no runners): always create the release locally via the CLI above — do not wait for CI.

---

## Capability-Based Enhancements

Apply these when the corresponding tool is available:

| Capability | Detection | Command |
|---|---|---|
| Signed tag | `git config user.signingkey` exits 0 | `git tag -s vX.Y.Z` |
| SBOM | `syft` in PATH | `syft . -o cyclonedx-json > sbom.cdx.json` |
| Provenance | `gh attestation` available (not GHES) | `gh attestation create --predicate-type slsa ...` |
| Immutable release | GitHub.com or GHES 3.12+ | `gh release create --make-latest` |

---

## Checklist

```
[ ] [Unreleased] has entries
[ ] Version confirmed with user
[ ] CHANGELOG.md updated: [vX.Y.Z](url) - YYYY-MM-DD
[ ] Version files bumped
[ ] make qa passes
[ ] Release PR committed and merged
[ ] git pull --ff-only on main
[ ] git tag -a vX.Y.Z (signed if key available)
[ ] git push origin vX.Y.Z (tag only)
[ ] Artifacts built + checksums generated (if applicable)
[ ] Platform release created with changelog notes
[ ] Release URL verified
```

---

## Quick Reference — Tool Routing

| Operation | MCP tool | Bash fallback |
|-----------|----------|---------------|
| Create platform release | `mcp__git-ops__create_release` | `gh release create` / `glab release create` |
| Release status | `mcp__git-ops__release_status` | manual git + CHANGELOG inspection |
