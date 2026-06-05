# Releasing PangoLock

This guide covers building a distributable, **signed and notarized** PangoLock
release. Notarization requires an **Apple Developer account** (a paid membership)
and a **Developer ID Application** certificate — these cannot be done in CI
without those credentials, so the maintainer runs the signed steps locally (or in
a CI job with secrets configured).

> A quick local (unsigned) build for testing:
> ```bash
> scripts/build-release.sh           # → dist/PangoLock-<version>.zip (unsigned)
> ```

## Prerequisites (for a distributable build)

- Apple Developer Program membership.
- A **Developer ID Application** certificate in your login keychain.
- Your **Team ID** (10 chars) and the certificate's identity string, e.g.
  `Developer ID Application: Your Name (TEAMID)`.
- An **app‑specific password** for notarization, stored as a notarytool profile.

Nothing secret is committed to this repo — provide these via environment/keychain
at build time. `CODE_SIGN_STYLE` defaults to Automatic and there is **no
`DEVELOPMENT_TEAM`** baked into the project.

## 1. Bump the version

- Update `MARKETING_VERSION` in `PangoLock.xcodeproj` (Debug + Release).
- Move the `CHANGELOG.md` *Unreleased* notes under a new `## [x.y.z]` heading.

## 2. Build & sign

```bash
DEVELOPMENT_TEAM=TEAMID \
SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
scripts/build-release.sh --sign
```

This produces `dist/PangoLock.app` (Release, hardened runtime + App Sandbox) and
`dist/PangoLock-<version>.zip`.

Verify the signature and that the runtime/entitlements are present:

```bash
codesign --verify --deep --strict --verbose=2 dist/PangoLock.app
codesign -d --entitlements :- dist/PangoLock.app
```

## 3. Notarize

Store credentials once as a notarytool keychain profile:

```bash
xcrun notarytool store-credentials PangoLock-Notary \
  --apple-id "you@example.com" --team-id TEAMID --password "APP_SPECIFIC_PASSWORD"
```

Submit and wait, then staple the ticket to the app:

```bash
xcrun notarytool submit dist/PangoLock-<version>.zip \
  --keychain-profile PangoLock-Notary --wait
xcrun stapler staple dist/PangoLock.app
```

Re‑zip the stapled app for distribution:

```bash
ditto -c -k --keepParent dist/PangoLock.app dist/PangoLock-<version>.zip
```

## 4. (Optional) DMG

```bash
hdiutil create -volname "PangoLock" -srcfolder dist/PangoLock.app \
  -ov -format UDZO dist/PangoLock-<version>.dmg
# Sign + notarize + staple the DMG the same way as the zip if distributing it.
```

## 5. Tag & publish

```bash
git tag -a v<version> -m "PangoLock v<version>"
git push origin v<version>
```

Create a GitHub Release for the tag, paste the `CHANGELOG.md` section, and attach
the notarized `.zip` (and `.dmg` if built). CI (build + tests) must be green on
`main` before tagging.

## Verifying a download (for users)

```bash
spctl -a -vv PangoLock.app        # should say: accepted, source=Notarized Developer ID
xcrun stapler validate PangoLock.app
```
