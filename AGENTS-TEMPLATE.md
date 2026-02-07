# AGENTS.md - {repo-name}

## Stack
- **Backend:** {backend stack}
- **Frontend:** {frontend stack}
- **Database:** {database}

## Required Agents

### Implementation
```yaml
agents:
  - role: backend-implementer
    scope: src/backend/
    skills:
      - {backend language}
      - API design
      - Database queries
      - Security best practices
    
  - role: frontend-implementer
    scope: src/frontend/
    skills:
      - {frontend framework}
      - TypeScript
      - Accessibility
      - Responsive design
```

### Review
```yaml
reviewers:
  - role: backend-reviewer
    focus:
      - Security vulnerabilities
      - SQL injection prevention
      - API consistency
      - Performance
      - Error handling
    
  - role: frontend-reviewer
    focus:
      - Accessibility (a11y)
      - Bundle size
      - UX patterns
      - Component reusability
```

### Domain Expert (Optional)
```yaml
sme:
  - role: domain-expert
    knowledge:
      - {business domain}
      - {specific features}
    docs:
      - {path to docs}
```

## Workflow Rules

### PR Creation
- One PR per issue
- Use `Closes #{issue}` in description
- Descriptive commit messages
- Follow existing code style

### Review Process
- All PRs require review from relevant reviewer(s)
- Backend changes → backend-reviewer
- Frontend changes → frontend-reviewer
- Full-stack changes → both reviewers

### Build Requirements
- All tests must pass
- No security vulnerabilities
- Lint/format checks pass

## CI/CD Pattern
```
┌───────────────┐  ┌─────────────────┐  ┌────────────────┐  ┌──────────────────┐
│ backend-test  │  │ backend-docker  │  │ frontend-test  │  │ frontend-docker  │
└───────┬───────┘  └────────┬────────┘  └───────┬────────┘  └────────┬─────────┘
        └───────────────────┴───────────────────┴────────────────────┘
                                       │
                    ┌──────────────────┼──────────────────┐
                    ▼                  ▼                  ▼
              PR: preview        main: test          main: prod
```

- **4 parallel jobs:** test + docker for each stack
- **Build happens in Docker** (multi-stage) - no separate build job
- **Deploy requires all 4 to pass**
- **PR → preview**, **main → test → prod**

## Context Files
- README.md
- {other important files}
