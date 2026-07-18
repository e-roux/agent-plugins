# Molecule 101: Configuration and Usage Guide

## How Molecule Discovers Roles

### Directory Structure Expected

Molecule expects to be run from within an Ansible role directory with this structure:

```
my_role/                      # Current working directory (role root)
├── molecule/                 # Molecule scenarios directory
│   ├── default/             # Default scenario
│   │   ├── molecule.yml     # Scenario configuration
│   │   ├── converge.yml     # Main test playbook
│   │   ├── prepare.yml      # Setup playbook (optional)
│   │   ├── verify.yml       # Verification playbook (optional)
│   │   └── Containerfile    # Custom container (optional)
│   ├── rpi4/               # Additional scenario for ARM64 testing
│   │   ├── molecule.yml
│   │   ├── converge.yml
│   │   └── Containerfile
│   └── ...
├── tasks/                   # Role tasks
│   └── main.yml
├── handlers/               # Role handlers
│   └── main.yml
├── defaults/               # Default variables
│   └── main.yml
├── vars/                   # Role variables
│   └── main.yml
├── templates/              # Jinja2 templates
├── files/                  # Static files
└── meta/                   # Role metadata
    └── main.yml
```

### Discovery Algorithm

1. **Project Directory**: Uses `MOLECULE_PROJECT_DIRECTORY` env var or current working directory
2. **Scenario Discovery**: Globs for `molecule/*/molecule.yml` files
3. **Role Validation**: Assumes current directory is the role being tested

### Environment Variables

- `MOLECULE_PROJECT_DIRECTORY`: Override base project directory
- `MOLECULE_GLOB`: Override scenario discovery pattern (default: `molecule/*/molecule.yml`)
- `ANSIBLE_COLLECTIONS_PATH`: Path to Ansible collections

## Basic Configuration

### Core molecule.yml Structure

```yaml
---
# Dependency management
dependency:
  name: galaxy                  # or 'shell', 'ansible-galaxy'
  command: /usr/bin/true        # (For 'shell' name only) Command to run for dependencies

# Infrastructure driver
driver:
  name: podman                  # or 'docker', 'vagrant', 'delegated'

# Test platforms/instances
platforms:
  - name: instance-1           # Instance name
    image: ubuntu:24.04        # Container image
    # OR for custom Dockerfile:
    dockerfile: Containerfile   # Custom container definition
    image: ubuntu:24.04        # Still needed for tagging
    
    # Container options
    systemd: false             # Enable systemd in container
    privileged: false          # Run privileged container
    volumes:                   # Volume mounts
      - /sys/fs/cgroup:/sys/fs/cgroup:rw
    tmpfs:                     # Temporary filesystems
      /run: "size=100m,noexec"
      /tmp: "size=100m"
    capabilities:              # Container capabilities
      - SYS_ADMIN
    command: /bin/systemd      # Override container command
    environment:               # Environment variables
      DEBIAN_FRONTEND: noninteractive

# Ansible provisioner
provisioner:
  name: ansible
  config_options:
    defaults:
      remote_tmp: /tmp/.ansible/tmp
      host_key_checking: false
  playbooks:
    converge: ${MOLECULE_PLAYBOOK:-converge.yml}
    prepare: prepare.yml       # Optional setup playbook
    verify: verify.yml         # Optional verification playbook

# Test scenario configuration
scenario:
  name: default               # Scenario name
  test_sequence:             # Execution sequence
    - dependency
    - cleanup
    - destroy
    - syntax
    - create
    - prepare
    - converge
    - idempotence
    - side_effect
    - verify
    - cleanup
    - destroy

# Test verification
verifier:
  name: testinfra            # or 'ansible'
  directory: tests           # Test files directory
```

## Common Drivers

### Podman Driver

```yaml
driver:
  name: podman
platforms:
  - name: instance
    image: ubuntu:24.04
    systemd: true
    volumes:
      - /sys/fs/cgroup:/sys/fs/cgroup:rw
    tmpfs:
      /run: "size=100m,noexec"
    capabilities:
      - SYS_ADMIN
    command: /lib/systemd/systemd      # /usr/lib/systemd/systemd for RedHat/CentOS
```

### Docker Driver

```yaml
driver:
  name: docker
platforms:
  - name: instance
    image: ubuntu:24.04
    privileged: true
    volumes:
      - /sys/fs/cgroup:/sys/fs/cgroup:ro
    command: /lib/systemd/systemd
```

### Vagrant Driver

```yaml
driver:
  name: vagrant
platforms:
  - name: instance
    box: ubuntu/noble64
    memory: 1024
    cpus: 2
```

## Custom Containerfiles

When using custom containers, create a `Containerfile` (or `Dockerfile`) in your scenario directory:

```dockerfile
FROM arm64v8/debian:trixie

ENV DEBIAN_FRONTEND=noninteractive

# Install systemd and essential packages
RUN apt-get update && \
    apt-get install -y \
        systemd \
        systemd-sysv \
        dbus \
        python3 \
        python3-apt \
        sudo \
        && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Configure systemd for container
RUN systemctl mask \
    dev-hugepages.mount \
    sys-fs-fuse-connections.mount \
    sys-kernel-config.mount \
    display-manager.service \
    graphical.target \
    systemd-logind.service

VOLUME ["/sys/fs/cgroup"]
CMD ["/lib/systemd/systemd"]
```

Then reference it in molecule.yml:

```yaml
platforms:
  - name: custom-container
    dockerfile: Containerfile
    image: arm64v8/debian:trixie  # Required: Molecule uses this as the tag name for the built image
    systemd: true
```

## Essential Playbooks

### converge.yml (Main Test Playbook)

```yaml
---
- name: Converge
  hosts: all
  become: true
  tasks:
    - name: Include role
      include_role:
        name: my_role
```

### prepare.yml (Setup Playbook)

```yaml
---
- name: Prepare
  hosts: all
  become: true
  tasks:
    - name: Update package cache
      package:
        update_cache: true

    - name: Install test dependencies
      package:
        name:
          - curl
          - git
        state: present
```

### verify.yml (Verification Playbook)

```yaml
---
- name: Verify
  hosts: all
  gather_facts: false
  tasks:
    - name: Check service is running
      service:
        name: my-service
        state: started
      register: service_status

    - name: Verify service is active
      assert:
        that:
          - service_status.status.ActiveState == "active"
        fail_msg: "Service is not running"
```

## Common Commands

```bash
# List available scenarios
molecule list

# Test specific scenario
molecule test --scenario-name rpi4

# Run individual steps
molecule create                    # Create instances
molecule prepare                   # Run prepare playbook
molecule converge                  # Run main playbook
molecule verify                    # Run verification
molecule destroy                   # Clean up instances

# Debug and troubleshooting
molecule login                     # SSH into instance
molecule login --host instance-1   # SSH into specific instance

# Syntax checking only
molecule syntax

# Test idempotence (run twice, should not change)
molecule idempotence

# Bootstrap a new scenario
molecule init scenario -d podman my_new_scenario

# Pass flags to Ansible (use '--' separator)
molecule converge -- -vvv
molecule test -- --check
```

## Advanced Configuration

### Multiple Platforms

```yaml
platforms:
  - name: ubuntu-24
    image: ubuntu:24.04
    
  - name: ubuntu-24
    image: ubuntu:24.04
    
  - name: centos-9
    image: quay.io/centos/centos:stream9
```

### Platform-Specific Variables

```yaml
platforms:
  - name: ubuntu-instance
    image: ubuntu:24.04
    groups:
      - ubuntu
    host_vars:
      ansible_python_interpreter: /usr/bin/python3
      
  - name: centos-instance
    image: quay.io/centos/centos:stream9
    groups:
      - centos
    host_vars:
      ansible_python_interpreter: /usr/bin/python3
```

### Custom Test Sequence

```yaml
scenario:
  test_sequence:
    - dependency
    - destroy
    - syntax
    - create
    - converge
    - verify
    - destroy

### Scenario-specific Linting

You can define custom linting rules that run during `molecule lint`:

```yaml
lint: |
  set -e
  uvx yamllint .
  ansible-lint .
```
```

### Environment-Specific Scenarios

Create different scenarios for different environments:

- `molecule/default/` - Basic functionality testing
- `molecule/rpi4/` - ARM64/Raspberry Pi testing  
- `molecule/production/` - Production-like environment
- `molecule/minimal/` - Minimal resource testing

## Troubleshooting

### Common Issues

1. **Collection Import Errors**:
   ```bash
   export ANSIBLE_COLLECTIONS_PATH=~/.ansible/collections
   ```

2. **Container Build Timeouts**:
   - Increase timeout in driver configuration
   - Use pre-built images when possible
   - Consider using multi-stage builds

3. **Systemd in Containers**:
   ```yaml
   platforms:
     - name: systemd-container
       image: ubuntu:22.04
       systemd: true
       volumes:
         - /sys/fs/cgroup:/sys/fs/cgroup:rw
       tmpfs:
         /run: "size=100m,noexec"
       capabilities:
         - SYS_ADMIN
       command: /lib/systemd/systemd
   ```

4. **ARM64 Testing**:
   - Use `arm64v8/` prefix for images
   - Expect longer build times due to emulation
   - Consider using native ARM64 runners for CI

### Debugging Tips

- Use `molecule login` to inspect instance state
- Check logs with `molecule --debug test`
- Validate syntax before full testing with `molecule syntax`
- Test incrementally: `create` → `converge` → `verify` → `destroy`

## Best Practices

1. **Start Simple**: Begin with basic scenarios and add complexity gradually
2. **Use Multiple Scenarios**: Test different platforms and configurations
3. **Idempotence Testing**: Always test that your role can run multiple times safely
4. **Verification**: Write comprehensive verify playbooks or use testinfra
5. **CI Integration**: Use Molecule in continuous integration pipelines
6. **Resource Management**: Always destroy instances after testing to free resources
7. **Documentation**: Document scenario purposes and any special requirements

## Real-World Example: ARM64 Testing

Based on our work with the mediaplayer role, here's a complete example for ARM64 testing:

### molecule/rpi4/molecule.yml
```yaml
---
dependency:
  name: shell
  command: /usr/bin/true
driver:
  name: podman
platforms:
  - name: rpi4-test
    dockerfile: Containerfile
    image: arm64v8/debian:trixie  # Required for filename generation
    systemd: true
    volumes:
      - /sys/fs/cgroup:/sys/fs/cgroup:rw
    tmpfs:
      /run: "size=100m,noexec"
      /tmp: "size=100m"
    capabilities:
      - SYS_ADMIN
    command: /lib/systemd/systemd
    environment:
      DEBIAN_FRONTEND: noninteractive
provisioner:
  name: ansible
  config_options:
    defaults:
      remote_tmp: /tmp/.ansible/tmp
  playbooks:
    converge: ${MOLECULE_PLAYBOOK:-converge.yml}
    prepare: prepare.yml
scenario:
  name: rpi4
verifier:
  name: testinfra
```

### Key Lessons Learned

1. **Both `dockerfile` and `image` required**: Molecule needs the `image` attribute even when using custom Containerfile
2. **Collections path**: Set `ANSIBLE_COLLECTIONS_PATH=~/.ansible/collections` for collection imports
3. **ARM64 emulation**: Expect longer build times when testing ARM64 on x64 systems
4. **Systemd configuration**: Proper volume mounts and capabilities needed for systemd containers
