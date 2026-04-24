# Changelog

## [Unreleased]

- feat: convert to mono-repo — remove rsync-from-sibling-repos workflow
- feat: add pi coding agent support for make, dev, infra, and web-browser plugins
- feat(dev): port all guards (secrets, comments, branch-first, migration, no-verify, pipeline-chainguard, secret-redaction) to pi TypeScript extension
- feat(make): port Makefile validator and command redirect guards to pi TypeScript extension
- feat(infra): port Ansible/Molecule guards to pi TypeScript extension
- feat(web-browser): add pi package.json — skills work as-is via Agent Skills standard
- chore: add verify-pi target to Makefile for pi package validation
- docs: update README with tri-agent compatibility table and pi install instructions
