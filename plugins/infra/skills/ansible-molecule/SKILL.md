---
name: ansible-molecule
description: Use this skill when working with Ansible playbooks, roles, collections, or Molecule testing.
---

# Working with Ansible and Molecule

This skill defines the mandatory standards and workflows for Ansible development in this project.

## Core Rules

1. **Podman Driver MANDATORY**: Always use the `podman` driver for Molecule. Docker, Vagrant, or other drivers are prohibited unless explicitly requested for edge cases.
2. **Molecule Testing MANDATORY**: All Ansible roles and collections MUST be tested using Molecule. No role should be considered complete without a passing Molecule scenario.
3. **Makefile Integration**: A `Makefile` at the project root is MANDATORY and must follow the `using-makefile` skill targets (`fmt`, `lint`, `test`, `check`, `qa`).
4. **Lint & Format**: Always run `ansible-lint` and `yamllint`. These should be integrated into the `make lint` and/or Molecule `lint` block.

## Recommended Project Structure

```text
project_root/
├── Makefile                # MANDATORY
├── molecule/               # Shared Molecule configs
├── roles/                  # Ansible roles
│   └── my_role/
│       ├── molecule/       # Role-specific scenarios
│       │   └── default/
│       │       └── molecule.yml
│       └── ...
└── ...
```

## Molecule Configuration Standards

### 1. Mandatory Podman Driver
```yaml
driver:
  name: podman
```

### 2. Standard Platforms
Use the latest stable images as documented in [molecule.md](../../../../doc/molecule/molecule.md):
- **Ubuntu**: `ubuntu:24.04` (LTS)
- **CentOS**: `quay.io/centos/centos:stream9`
- **Debian**: `debian:bookworm` or `debian:12`

### 3. Integrated Linting
Always include a `lint` block in `molecule.yml`:
```yaml
lint: |
  set -e
  yamllint .
  ansible-lint .
```

## Workflow Protocol

Follow this sequence when developing:

1.  **Initialize**: `molecule init scenario -d podman default` (if missing).
2.  **Lint/Format**: `make lint` (Ensure `ansible-lint` and `yamllint` are called).
3.  **Test**: `molecule test` (or `make test` which calls Molecule).
4.  **Idempotence**: Always verify the role is idempotent.
5.  **Quality Gate**: `make qa` MUST pass before completion.

## References
For detailed configuration examples, command syntax, and troubleshooting, refer to the [Molecule 101 Guide](../../../../doc/molecule/molecule.md).
