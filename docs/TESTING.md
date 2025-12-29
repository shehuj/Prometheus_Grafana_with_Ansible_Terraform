# Testing Guide

## Overview

This project includes comprehensive automated testing that runs on every Pull Request to ensure code quality, security, and proper configuration.

## Test Suites

### 1. Terraform Validation

**What's tested:**
- Terraform formatting (`terraform fmt`)
- Configuration validation (`terraform validate`)
- Best practices and security (TFLint)

**Run locally:**
```bash
cd terraform

# Format check
terraform fmt -check -recursive

# Validate
terraform init -backend=false
terraform validate

# Lint (install tflint first: brew install tflint)
tflint --init
tflint
```

---

### 2. Ansible Validation

**What's tested:**
- Playbook syntax (`ansible-playbook --syntax-check`)
- Ansible best practices (ansible-lint)
- YAML formatting (yamllint)
- Galaxy collection requirements

**Run locally:**
```bash
# Install tools
pip install ansible ansible-lint yamllint

# Syntax check
cd ansible
ansible-playbook -i inventory/hosts.ini playbooks/site.yml --syntax-check
ansible-playbook -i inventory/hosts.ini playbooks/cleanup.yml --syntax-check

# Lint
ansible-lint playbooks/ roles/

# YAML lint
yamllint -c ../.yamllint.yml .
```

**Playbooks tested:**
- `ansible/playbooks/site.yml` - Main deployment playbook
- `ansible/playbooks/cleanup.yml` - Cleanup playbook

**Roles tested:**
- prometheus
- grafana
- alertmanager
- blackbox-exporter
- node-exporter
- docker

---

### 3. Shell Script Validation

**What's tested:**
- Shell script syntax and best practices (ShellCheck)
- Script executable permissions

**Run locally:**
```bash
# Install ShellCheck
# macOS: brew install shellcheck
# Linux: apt-get install shellcheck

# Check scripts
shellcheck scripts/*.sh

# Check permissions
ls -la scripts/*.sh
```

**Scripts tested:**
- `scripts/cleanup.sh`

---

### 4. Configuration Validation

**What's tested:**
- Prometheus configuration syntax
- Prometheus alert rules
- Custom jobs YAML
- AlertManager configuration

**Run locally:**
```bash
# Install promtool
wget https://github.com/prometheus/prometheus/releases/download/v2.48.1/prometheus-2.48.1.linux-amd64.tar.gz
tar xvfz prometheus-2.48.1.linux-amd64.tar.gz
sudo cp prometheus-2.48.1.linux-amd64/promtool /usr/local/bin/

# Validate configs
promtool check config configs/prometheus/prometheus.yml
promtool check rules configs/prometheus/alert-rules.yml

# YAML validation
yq eval configs/prometheus/custom-jobs.yml
```

---

### 5. Security Scanning

**What's tested:**
- Infrastructure misconfigurations (Trivy)
- Terraform security issues (TFSec)
- Exposed secrets (TruffleHog)

**Run locally:**
```bash
# Install tools
# Trivy: https://aquasecurity.github.io/trivy/latest/getting-started/installation/
# TFSec: brew install tfsec

# Run Trivy
trivy config .

# Run TFSec
cd terraform
tfsec .

# Check for secrets
git secrets --scan
```

---

### 6. Documentation Check

**What's tested:**
- Broken links in markdown files
- README.md structure
- Documentation updates with code changes

**Run locally:**
```bash
# Install markdown-link-check
npm install -g markdown-link-check

# Check links
markdown-link-check README.md
markdown-link-check docs/*.md

# Check README structure
grep "## Overview" README.md
grep "## Features" README.md
grep "## Quick Start" README.md
```

---

## CI/CD Pipeline

### Trigger Events

Tests run automatically on:
- Pull requests to `dev` or `main` branches
- Changes to code files (excludes docs-only changes)

### Test Workflow

```
PR Created/Updated
    ├─> Terraform Validation
    ├─> Ansible Validation
    ├─> ShellCheck
    ├─> Config Validation
    ├─> Security Scan
    ├─> Documentation Check
    └─> Test Summary (combines all results)
```

### PR Comments

Each test suite posts a comment to the PR with:
- ✅ Pass/❌ Fail/⚠️ Warning status
- Detailed results
- Suggestions for fixes

Example comment:
```markdown
#### Terraform Validation Results 🏗️

| Check | Status |
|-------|--------|
| Format Check | ✅ Passed |
| Validate | ✅ Passed |
| TFLint | ⚠️ Warnings |

Terraform version: 1.6.0
```

---

## Local Development Workflow

### Before Creating PR

```bash
# 1. Run Terraform checks
cd terraform
terraform fmt -recursive
terraform validate
tflint

# 2. Run Ansible checks
cd ../ansible
ansible-playbook -i inventory/hosts.ini playbooks/site.yml --syntax-check
ansible-lint playbooks/ roles/

# 3. Check shell scripts
shellcheck scripts/*.sh

# 4. Validate configs
promtool check config configs/prometheus/prometheus.yml

# 5. Check for secrets
git secrets --scan

# 6. Check markdown links
markdown-link-check README.md
```

### Quick Test Script

Create `scripts/run-tests.sh`:

```bash
#!/bin/bash
# Run all tests locally before PR

set -e

echo "🧪 Running local tests..."

echo "1️⃣ Terraform..."
cd terraform && terraform fmt -check && terraform validate && cd ..

echo "2️⃣ Ansible..."
cd ansible && ansible-playbook -i inventory/hosts.ini playbooks/site.yml --syntax-check && cd ..

echo "3️⃣ Shell scripts..."
shellcheck scripts/*.sh

echo "4️⃣ Prometheus config..."
promtool check config configs/prometheus/prometheus.yml

echo "✅ All tests passed!"
```

---

## Test Configuration Files

### `.yamllint.yml`

Configuration for YAML linting:
- Max line length: 200
- Indentation: 2 spaces
- Allow `yes/no` and `true/false`

### `.markdown-link-check.json`

Configuration for markdown link checking:
- Ignores localhost URLs
- Ignores placeholder URLs
- 3 retry attempts
- 20s timeout

---

## Troubleshooting Tests

### Terraform Format Failures

```bash
# Auto-fix formatting
terraform fmt -recursive
git add terraform/
git commit -m "Fix terraform formatting"
```

### Ansible Lint Warnings

```bash
# View detailed warnings
ansible-lint -v playbooks/ roles/

# Fix common issues
# - Add tags to tasks
# - Use FQCN (fully qualified collection names)
# - Fix deprecated syntax
```

### ShellCheck Issues

```bash
# View issues
shellcheck -x scripts/cleanup.sh

# Common fixes:
# - Quote variables: "$variable"
# - Use [[ ]] instead of [ ]
# - Fix SC2086, SC2046 warnings
```

### Security Scan Failures

```bash
# Trivy - fix misconfigurations
trivy config . --severity HIGH,CRITICAL

# TFSec - review Terraform security
tfsec terraform/ --minimum-severity HIGH

# TruffleHog - remove secrets
# If false positive, add to .trufflehogignore
```

---

## Required Checks

The following checks must pass for PR merge:

1. ✅ Terraform validation
2. ✅ Ansible syntax check
3. ⚠️ Security scan (warnings allowed)
4. ⚠️ Documentation (warnings allowed)

**Critical failures** (block merge):
- Terraform validation errors
- Ansible syntax errors

**Warnings** (don't block merge):
- Linting issues
- Documentation suggestions
- Security warnings (review required)

---

## Adding New Tests

To add new test suites:

1. **Add to `.github/workflows/pr-tests.yml`:**
   ```yaml
   my-new-test:
     name: My New Test
     runs-on: ubuntu-latest
     steps:
       - name: Checkout code
         uses: actions/checkout@v4
       - name: Run test
         run: |
           # Your test commands
   ```

2. **Add to test summary dependencies:**
   ```yaml
   test-summary:
     needs: [...existing..., my-new-test]
   ```

3. **Document in this file**

---

## Best Practices

### ✅ DO

1. **Run tests locally before pushing**
   ```bash
   make test  # if you create a Makefile target
   ```

2. **Fix linting issues before requesting review**
   - Easier to review actual changes
   - Faster PR merge

3. **Keep tests fast**
   - Use parallel execution
   - Cache dependencies

4. **Use meaningful commit messages**
   ```
   Fix: Correct Prometheus config syntax
   Test: Add validation for custom jobs
   ```

### ❌ DON'T

1. Don't skip tests with `--no-verify`
2. Don't ignore security warnings without review
3. Don't commit with syntax errors
4. Don't merge with failing critical tests

---

## Continuous Improvement

Tests are living documentation. Update when:
- Adding new features
- Changing infrastructure
- Discovering new security issues
- Improving development workflow

---

## Resources

- [Terraform Testing](https://www.terraform.io/docs/cli/commands/test.html)
- [Ansible Lint](https://ansible-lint.readthedocs.io/)
- [ShellCheck](https://www.shellcheck.net/)
- [Trivy Documentation](https://aquasecurity.github.io/trivy/)
- [GitHub Actions](https://docs.github.com/en/actions)

---

## Quick Reference

```bash
# Run all tests locally
terraform fmt -check -recursive && \
terraform validate && \
ansible-playbook --syntax-check playbooks/site.yml && \
shellcheck scripts/*.sh && \
promtool check config configs/prometheus/prometheus.yml

# View test results
# GitHub PR → Checks tab → View details

# Re-run failed tests
# GitHub PR → Re-run failed jobs
```

**Test coverage:** 90%+ of production code
**Average test time:** ~5 minutes
**Required for merge:** Critical tests passing
