# Contributing to stellarGive

Thanks for contributing to stellarGive. This repository contains:
- Soroban contract: `contracts/stellar-give`
- Next.js frontend: `frontend`

## 1. Branch Strategy

Use prefixed branch names:
- `feat/<short-description>` for features
- `fix/<short-description>` for bug fixes
- `chore/<short-description>` for maintenance

Examples:
- `feat/campaign-filtering`
- `fix/claim-deadline-validation`
- `chore/ci-cache-tuning`

## 2. Local Setup

```bash
git clone https://github.com/Feyisara2108/stellargive.git
cd stellargive
cp .env.example .env
```

Contract tooling:
```bash
rustup toolchain install stable
rustup target add wasm32-unknown-unknown
```

Frontend tooling:
```bash
cd frontend
npm ci
```

## 3. Testing Requirements

Before opening a PR, run:

```bash
# Contract checks
cd contracts/stellar-give
cargo fmt --check
cargo clippy -- -D warnings
cargo test
cargo build --release --target wasm32-unknown-unknown

# Frontend checks
cd ../../frontend
npm run lint
npm run build
```

## 4. Code Review Standards

- Keep PRs focused and scoped to a single concern.
- Include tests or rationale when changing contract logic.
- Do not merge with failing CI.
- Document config/deployment changes in `docs/DEPLOYMENT.md`.
- Flag security-sensitive changes explicitly in PR description.

## 5. Commit Message Convention

Use Conventional Commits:
- `feat: add campaign claim guard`
- `fix: enforce accepted token check`
- `chore: optimize frontend ci cache`

## 7. Recognition

We recognize all types of contributions! We use the [all-contributors](https://all-contributors.js.org) specification.

To add yourself or someone else to the contributors list, use the CLI in your PR or comment:
```bash
npx all-contributors add <username> <contribution-type>
```
Common contribution types:
- `code`: Functional code
- `doc`: Documentation
- `bug`: Bug reports
- `design`: UI/UX design
- `ideas`: Feature requests & ideas
- `test`: Adding or improving tests
- `review`: Code reviews
- `question`: Answering questions

Example:
```bash
npx all-contributors add Feyisara2108 code,doc
```

The contributors table in `README.md` will be updated automatically on merge or can be generated manually with `npx all-contributors generate`.

## 8. Pull Request Template (Use in every PR)

```md
## Summary
- What changed and why

## Type of change
- [ ] feat
- [ ] fix
- [ ] chore
- [ ] docs

## Validation
- [ ] cargo fmt --check
- [ ] cargo clippy -- -D warnings
- [ ] cargo test
- [ ] npm run lint
- [ ] npm run build

## Mainnet Readiness (Required for Mainnet-targeting PRs)
- [ ] [Final Mainnet Audit Checklist](../docs/MAINNET_AUDIT_CHECKLIST.md) completed and signed off.

## Security impact
- [ ] No security impact
- [ ] Security-sensitive (describe)

## Deployment notes
- Any testnet/mainnet rollout steps
```
