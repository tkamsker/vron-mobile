# Git Workflow & Release Process

## Branch Strategy

This project follows a three-tier branching strategy with semantic versioning and automated releases.

### Branch Hierarchy

```
main (production)
  ↑
stage (pre-release)
  ↑
dev (development)
  ↑
feature/* (feature branches)
```

### Branch Purposes

- **`dev`**: Development branch - integration point for all features
  - Automatically deploys to TestFlight (development track)
  - Used for active development and testing
  - Always deployable but may contain experimental features

- **`stage`**: Staging branch - pre-production testing
  - Automatically deploys to TestFlight (staging/beta track)
  - Final validation before production
  - Must be stable and thoroughly tested

- **`main`**: Production branch - live releases
  - Protected branch requiring pull request reviews
  - Automatically creates GitHub releases
  - Deploys to App Store production

## Workflow Process

### 1. Feature Development

```bash
# Create feature branch from dev
git checkout dev
git pull origin dev
git checkout -b feature/US1-authentication

# Work on your feature...
# Make commits following conventional commit format

# Push feature branch
git push origin feature/US1-authentication
```

### 2. Conventional Commits

All commits MUST follow the [Conventional Commits](https://www.conventionalcommits.org/) specification:

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

#### Commit Types

- `feat:` - New feature (triggers MINOR version bump)
- `fix:` - Bug fix (triggers PATCH version bump)
- `docs:` - Documentation only changes
- `style:` - Code style changes (formatting, etc.)
- `refactor:` - Code refactoring
- `perf:` - Performance improvements
- `test:` - Adding or updating tests
- `build:` - Build system or dependencies changes
- `ci:` - CI/CD configuration changes
- `chore:` - Other changes (maintenance, etc.)

#### Breaking Changes

Add `!` after type or `BREAKING CHANGE:` in footer for MAJOR version bumps:

```
feat!: redesign authentication flow

BREAKING CHANGE: API endpoints have changed
```

#### Examples

```bash
# Feature commits
git commit -m "feat(auth): add user login functionality"
git commit -m "feat(projects): implement project list view"

# Bug fixes
git commit -m "fix(auth): resolve token expiration issue"
git commit -m "fix(upload): handle network timeout errors"

# Breaking changes
git commit -m "feat(api)!: redesign GraphQL schema"
```

### 3. User Story Completion

After completing a user story:

```bash
# Ensure all changes are committed with proper feat: prefixes
git status

# Create a summary commit for the user story
git commit -m "feat(US1): complete user authentication

- Email/password login
- Token management
- Offline auth state restoration
- User profile caching

Closes #US1"

# Push to dev branch
git push origin feature/US1-authentication

# Create Pull Request to dev
gh pr create --base dev --title "feat(US1): User Authentication" --body "Completes User Story 1 - Authentication system with offline support"
```

### 4. Promotion Flow

#### Dev → Stage

```bash
# After features are tested in dev
git checkout stage
git pull origin stage
git merge dev --no-ff -m "chore(release): merge dev to stage for v1.1.0"
git push origin stage

# This triggers:
# - Automated tests
# - Build and deploy to TestFlight (staging track)
# - Version bump calculation
```

#### Stage → Main (Production Release)

```bash
# After validation in stage
git checkout main
git pull origin main
git merge stage --no-ff -m "chore(release): merge stage to main for v1.1.0"
git push origin main

# This triggers:
# - Automated tests
# - Production build
# - GitHub Release creation
# - App Store deployment (manual approval)
# - CHANGELOG generation
```

## Semantic Versioning

Versions follow [Semantic Versioning](https://semver.org/) (MAJOR.MINOR.PATCH):

- **MAJOR**: Breaking changes (e.g., 1.0.0 → 2.0.0)
- **MINOR**: New features, backward compatible (e.g., 1.0.0 → 1.1.0)
- **PATCH**: Bug fixes, backward compatible (e.g., 1.0.0 → 1.0.1)

### Version Calculation

The CI/CD pipeline automatically calculates the next version based on commit messages:

- `feat:` commits → MINOR bump
- `fix:` commits → PATCH bump
- `feat!:` or `BREAKING CHANGE:` → MAJOR bump
- Other types → No version bump

## CI/CD Pipeline

### Automated Workflows

1. **Pull Request Checks** (all branches)
   - Run tests
   - Lint code
   - Build verification
   - Code coverage report

2. **Dev Branch** (on push)
   - Run full test suite
   - Build IPA
   - Upload to TestFlight (development track)
   - Generate build number

3. **Stage Branch** (on push)
   - Run full test suite
   - Build IPA with staging config
   - Upload to TestFlight (staging/beta track)
   - Calculate next version
   - Create pre-release tag

4. **Main Branch** (on push)
   - Run full test suite
   - Build production IPA
   - Create GitHub Release with CHANGELOG
   - Upload to TestFlight (production track)
   - Generate release notes from commits

### TestFlight Tracks

- **Development** (`dev` branch): Internal testing, may contain experimental features
- **Staging** (`stage` branch): Beta testing, stable builds for external testers
- **Production** (`main` branch): Release candidates for App Store submission

## Release Process

### Complete Release Workflow

1. **Develop Features** on feature branches
2. **Merge to dev** via PR → TestFlight (development)
3. **Test in dev** → iterate if needed
4. **Merge to stage** when ready → TestFlight (staging)
5. **Beta test in stage** → final validation
6. **Merge to main** for release → Production + GitHub Release

### Hotfix Process

For urgent production fixes:

```bash
# Create hotfix branch from main
git checkout main
git pull origin main
git checkout -b hotfix/critical-auth-bug

# Fix the issue
git commit -m "fix(auth)!: resolve critical token validation bug"

# Merge to main
git checkout main
git merge hotfix/critical-auth-bug
git push origin main

# Backport to stage and dev
git checkout stage
git merge main
git push origin stage

git checkout dev
git merge stage
git push origin dev
```

## Best Practices

### Commit Guidelines

1. **One logical change per commit**: Each commit should represent a single, complete change
2. **Write descriptive commit messages**: Explain what and why, not how
3. **Reference issues**: Use `Closes #123` or `Refs #456` in commit messages
4. **Keep commits atomic**: Small, focused commits are easier to review and revert

### Pull Request Guidelines

1. **Keep PRs focused**: One user story or feature per PR
2. **Write detailed descriptions**: Explain changes, testing, and impact
3. **Request reviews**: At least one approval required for stage/main
4. **Run tests locally**: Ensure all tests pass before pushing
5. **Update documentation**: Keep docs in sync with code changes

### Release Timing

- **Dev deploys**: Continuously as features are merged
- **Stage deploys**: After feature completion, before major releases
- **Main deploys**: Weekly releases (or as needed for major features/fixes)

## Troubleshooting

### Merge Conflicts

```bash
# When merging dev → stage or stage → main
git checkout stage
git merge dev

# If conflicts occur:
# 1. Resolve conflicts in files
# 2. Mark as resolved
git add .
git commit -m "chore(merge): resolve conflicts from dev"
git push origin stage
```

### Failed CI/CD Build

1. Check GitHub Actions logs for error details
2. Fix issues locally and push fixes
3. CI will automatically re-run on push
4. For TestFlight issues, check App Store Connect

### Version Mismatch

If semantic-release calculates wrong version:

1. Review recent commit messages for correct prefixes
2. Manually tag if needed: `git tag v1.2.3`
3. Push tag: `git push origin v1.2.3`
4. CI will use the tag for builds

## Required Setup

### Repository Secrets

Add these secrets to GitHub repository settings:

- `APP_STORE_CONNECT_API_KEY_ID`: App Store Connect API Key ID
- `APP_STORE_CONNECT_ISSUER_ID`: App Store Connect Issuer ID
- `APP_STORE_CONNECT_API_KEY`: App Store Connect API Key (base64)
- `MATCH_PASSWORD`: Fastlane Match password
- `MATCH_GIT_URL`: Git URL for certificates repository

### Local Development

```bash
# Install dependencies
flutter pub get

# Set up environment
cp .env.example .env

# Configure git hooks (optional)
git config core.hooksPath .githooks
```

## References

- [Conventional Commits](https://www.conventionalcommits.org/)
- [Semantic Versioning](https://semver.org/)
- [Fastlane Documentation](https://docs.fastlane.tools/)
- [GitHub Actions for Flutter](https://docs.github.com/en/actions)
