# Changelog

All notable changes to the singularity plugin are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html) as described in [Versions and releases](README.md#versions-and-releases).

Add a line under `[Unreleased]` with every change to the plugin. `node scripts/version.js bump <level>` turns those lines into a release.

## [Unreleased]

## [0.1.0] - 2026-10-13

### Added

- Plugin with six roles (spec, plan, implement, review, verify, learn) plus the workflow optimizer.
- `/singularity:feature`, `/singularity:deep-review`, `/singularity:learn`, `/singularity:optimize`, `/singularity:init-project`.
- Tracker adapters for Jira, GitHub and GitLab.
- Per-project experience, eval cases and optimization archive.
- Shared engineering standards preloaded into every code-facing role.
- CI: lint, manifest validation, eval-case smoke check, gitleaks and internal-information checks.
- Versioned releases: the version lives in `plugin.json`, `scripts/version.js` checks it and prepares releases, and merging a version bump tags `singularity--v<version>`, moves the `stable` branch and publishes a GitHub release.
- Projects follow the `stable` branch (`ref: stable` in the `init-project` settings template), so they only receive released versions.
- Run digests record the `plugin_version` each run used, so the optimizer can compare releases.

[Unreleased]: https://github.com/hlistan/singularity/compare/singularity--v0.1.0...HEAD
[0.1.0]: https://github.com/hlistan/singularity/releases/tag/singularity--v0.1.0
