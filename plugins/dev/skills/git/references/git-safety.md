---
name: git-safety
description: Git commit safety and validation rules. Covers credential scanning, pre-commit checks, forbidden destructive operations, and safe workflows.
---

# Git Commit Safety Rules

**Purpose**: Ensure safe commits without exposing credentials or losing work.

## Pre-Commit Security Checks (MANDATORY)

### Credential Scanning
- **Never commit credentials** - passwords, tokens, API keys, auth files
- **Scan staged files** for sensitive data before any commit
- **Check file patterns** - avoid `*auth*`, `*secret*`, `*password*`, `*token*`, `*.key`
- **Review .gitignore** - ensure sensitive files are excluded

### Content Validation  
- **Read file contents** - understand what's being committed
- **Check `git status`** - verify only intended files are staged
- **Run `git diff --cached`** - review all staged changes
- **Validate commit scope** - ensure changes match stated purpose

## Commit Message Standards

### Format Requirements
```
<type>(<scope>): <description>

<body>
<footer>
```

### Type Conventions
- `feat:` - New feature or functionality
- `fix:` - Bug fix
- `chore:` - Maintenance, config updates
- `docs:` - Documentation changes
- `test:` - Test additions or updates
- `refactor:` - Code restructuring without behavior change

### Content Guidelines
- **Be descriptive** - explain WHY, not just WHAT
- **Follow project patterns** - match existing commit style
- **Include impact summary** - what this accomplishes
- **Use imperative mood** - "Add feature" not "Added feature"

## Pre-Commit Checklist

Before any `git commit`:
```bash
# 1. Review what's being committed
git status
git diff --cached

# 2. Check for sensitive content
git diff --cached | grep -i -E "(password|token|key|secret|auth)"

# 3. Verify commit scope
git log --oneline -3  # Check recent context

# 4. Test if applicable
# Run relevant tests for changed components
```

## Forbidden Operations (Require Explicit Permission)

**NEVER execute these commands without asking first:**

### Destructive Git Operations
- `git reset --hard` - **DESTROYS WORKING DIRECTORY CHANGES**
- `git filter-branch` - **REWRITES HISTORY** 
- `git rebase -i` - **INTERACTIVE REWRITING**
- `git push --force` - **OVERWRITES REMOTE HISTORY**
- `git branch -D` - **FORCE DELETES BRANCHES**

### Large-Scale Changes
- Adding/removing many files without review
- Committing binary files over 1MB
- Making changes across multiple shell configurations simultaneously

### When Uncertain
- **Always ask** - "Should I commit this?" 
- **Explain intent** - "I want to commit X to achieve Y"
- **Request permission** - "Can I run `git reset --soft` to fix this?"

## Emergency Procedures

### If Credentials Are Committed
1. **STOP immediately** - don't push
2. **Use `git reset --soft`** to preserve work while removing commits
3. **Remove sensitive files** from staging area
4. **Alert user** to revoke exposed credentials
5. **Add .gitignore patterns** to prevent reoccurrence

### If Work Is Lost
1. **Check `git reflog`** - commits are usually recoverable
2. **Look for backup files** - `*.backup`, `*.tmp`
3. **Check shell history** - recent file operations
4. **Search for auto-saves** - editor temp files

## Safe Operation Examples

### Good Commit Flow
```bash
# 1. Stage specific files
git add dots/zsh/config/site-functions/_newfunction

# 2. Review what's staged  
git diff --cached

# 3. Check for sensitive content
git diff --cached | grep -i token  # Should return nothing

# 4. Commit with good message
git commit -m "feat(zsh): add completion function for newtool

- Add comprehensive completion for newtool CLI
- Support all command flags and subcommands  
- Include file path completion for config files

Enhances zsh completion ecosystem with modern tool support."
```

### Safe File Removal
```bash
# Remove sensitive file safely
git reset HEAD dots/containers/config/auth.json  # Unstage
rm dots/containers/config/auth.json              # Delete
echo "config/auth.json" >> dots/containers/.gitignore  # Prevent future commits
```

## Daily Workflow Checklist

Before starting work:
- [ ] `git status` - understand current state
- [ ] `git log --oneline -5` - review recent commits
- [ ] Check for sensitive files in working directory

Before each commit:
- [ ] Review staged changes: `git diff --cached`
- [ ] Scan for credentials: `git diff --cached | grep -i -E "(password|token|secret)"`
- [ ] Write descriptive commit message
- [ ] Verify commit scope matches intent

End of session:
- [ ] Review all commits: `git log --oneline -10`
- [ ] Check working directory is clean: `git status`
- [ ] Ensure no sensitive files remain: `find . -name "*auth*" -o -name "*secret*"`

## Summary

**Key Rules**:
1. **Never commit credentials** = scan all staged files first
2. **Ask before destructive operations** = `git reset --hard`, `git push --force`, etc.
3. **Use descriptive commit messages** = explain WHY, not just WHAT  
4. **Review before committing** = `git diff --cached` every time
5. **When uncertain** = ask for permission before proceeding
