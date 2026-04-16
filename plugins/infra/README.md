# agent-plugin-infra

GitHub Copilot CLI plugin for infrastructure development: Ansible roles and collections with Molecule testing.

## Skills

| Skill | Trigger |
|-------|---------|
| `ansible-molecule` | Ansible playbooks, roles, collections, Molecule testing |

## Requirements

- [ansible-lint](https://ansible-lint.readthedocs.io/)
- [molecule](https://molecule.readthedocs.io/) with podman driver
- Make (`make lint`, `make test`, `make qa`)

## Installation

```bash
copilot plugin install gh:e-roux/agent-plugin-infra
```

To update to the latest version:

```bash
copilot plugin marketplace update
```

Verify the plugin is loaded with `/env` — it lists active plugins, skills, and hooks.
