<!-- Thanks for contributing to PangoLock! -->

## Summary

<!-- What does this PR do and why? Link any related issue: Closes #123 -->

## Type of change

- [ ] Bug fix
- [ ] New feature
- [ ] Refactor / chore
- [ ] Docs

## How was this tested?

<!-- Commands run, scenarios covered. -->

```
xcodebuild test -project PangoLock.xcodeproj -scheme PangoLock \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO -derivedDataPath build
```

- [ ] `xcodebuild test` passes (build + unit tests green)
- [ ] Added/updated tests for the change
- [ ] Manual steps that can't be tested headlessly are listed below

<!-- e.g. Touch ID, camera capture, Dock-hide, sandbox enforcement, UI clicks -->

## Security checklist

- [ ] No plaintext secrets written to disk or logs
- [ ] No paywall / StoreKit / feature‑gating introduced
- [ ] Destructive operations keep a confirmation/guardrail
- [ ] `SECURITY.md` / `docs/ARCHITECTURE.md` updated if the threat model changed
- [ ] `CHANGELOG.md` updated under *Unreleased*
