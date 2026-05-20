---
name: infra
description: "Infrastructure development plugin for Ansible roles and collections with Molecule testing (Podman driver), IaC conventions, and Make-centric workflow."
---

# Infrastructure Development — Active

## Ansible + Molecule Standards

### Mandatory Rules

1. **Podman driver only** — always use `driver: podman` in Molecule scenarios. Docker and Vagrant are prohibited unless explicitly requested.
2. **Molecule testing mandatory** — every Ansible role must have a passing Molecule scenario before it is considered complete.
3. **Makefile required** — a `Makefile` at project root is mandatory, following the make-first workflow (`fmt`, `lint`, `test`, `check`, `qa` targets).
4. **Lint always** — run `ansible-lint` and `yamllint`; integrate into `make lint`.

### Recommended Project Structure

```
project_root/
├── Makefile                # MANDATORY
├── molecule/               # Shared Molecule configs
├── roles/
│   └── my_role/
│       ├── molecule/
│       │   └── default/
│       │       └── molecule.yml
│       └── tasks/
│           └── main.yml
└── requirements.yml
```

### Molecule Scenario Template

```yaml
driver:
  name: podman
platforms:
  - name: instance
    image: "registry.access.redhat.com/ubi9/ubi-init:latest"
    pre_build_image: true
provisioner:
  name: ansible
verifier:
  name: ansible
```

### Make Targets

```makefile
lint:
  ansible-lint
  yamllint .

test:
  molecule test

qa: lint test
```

## Skills Available

- **ansible-molecule** — activate for Ansible/Molecule task guidance (Podman driver, scenario structure, lint configuration)
