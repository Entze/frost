# GitHub Actions Workflow Instructions

---
applyTo: ".github/workflows/**/*.yml,.github/workflows/**/*.yaml"
---

When generating or improving GitHub Actions workflows for this project:

## Security First

- Use GitHub secrets for sensitive data, never hardcode credentials
- Pin third-party actions to specific commits by using the SHA value (e.g., `- uses: owner/some-action@a824008085750b8e136effc585c3cd6082bd575f`)
- Configure minimal permissions for GITHUB_TOKEN required for the workflow

## Performance Essentials

- Cache dependencies with `actions/cache` or built-in cache options
- Add `timeout-minutes` to prevent hung workflows
- Use matrix strategies for multi-environment testing

## Best Practices

- Use descriptive names for workflows, jobs, and steps
- Include appropriate triggers: `push`, `pull_request`, `workflow_dispatch`
- Add `if: always()` for cleanup steps that must run regardless of failure

## Project-Specific Patterns

### Mise Integration

This project uses [mise](https://mise.jdx.dev/) for tool version management:

```yaml
- uses: jdx/mise-action@v3
  with:
    install: true        # Install tools from mise.toml
    cache: true          # Cache installed tools
    experimental: true   # Enable experimental features
```

Set `install: false` and `cache: false` explicitly when the job only runs mise tasks without needing the project's dev-dependencies installed (e.g., checking for file existence).

## References

- **GitHub Actions Documentation**
  - [Workflow syntax](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions)
  - [Security hardening](https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions)
  - [Using jobs](https://docs.github.com/en/actions/using-jobs)
  - [Caching dependencies](https://docs.github.com/en/actions/using-workflows/caching-dependencies-to-speed-up-workflows)

- **Third-Party Actions**
  - [jdx/mise-action](https://github.com/jdx/mise-action) - Mise tool version manager
  - [EndBug/add-and-commit](https://github.com/EndBug/add-and-commit) - Automated git commits
  - [softprops/action-gh-release](https://github.com/softprops/action-gh-release) - GitHub release creation

- **Project Documentation**
  - [CONTRIBUTING.md](../../CONTRIBUTING.md) - Release process and version management
