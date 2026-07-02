# Publishing Guide — Dyslexic Reader to Google Play (Free)

A zero-to-published, step-by-step guide. Follow it top to bottom. The two slow,
calendar-time gates — **identity verification** and the **new-account 14-day
closed-testing requirement** — are flagged with ⏳; **start those early**.

Companion doc: `docs/STORE_LISTING.md` has every store-listing field value and
the Data Safety / content-rating answers to paste in.

**App facts (verified against the repo):**

| Fact | Value | Source |
|---|---|---|
| App name | Dyslexic Reader | `lib/app/app_info.dart` (`kAppName`), `res/values/strings.xml` |
| Package / applicationId | `com.dobosp.dyslexic_reader` | `android/app/build.gradle.kts`, manifest |
| Version | `1.0.0+1` → versionName `1.0.0`, versionCode `1` | `pubspec.yaml`, `app_info.dart` |
| minSdk | 24 (Android 7.0) | `android/app/build.gradle.kts` |
| compileSdk / targetSdk | resolve to **36** (from the Flutter SDK) | `flutter.compileSdkVersion` / `flutter.targetSdkVersion` |
| Permissions | `INTERNET` only | `android/app/src/main/AndroidManifest.xml` |
| Release output | `build/app/outputs/bundle/release/app-release.aab` | `.github/workflows/build.yml` |

> **targetSdk note:** Google Play requires new apps to target **API 35**
> (Android 15) for submissions since 31 Aug 2025. This app resolves
> compile/target SDK to **36** via the Flutter SDK, so it **already exceeds**
> the requirement — no action needed.

---

## Step 0 — Prerequisites

- The Flutter SDK (stable) on your machine, or rely on CI to build.
- A Google account for the developer registration.
- The repo cloned, `flutter pub get` run, `flutter analyze` + `flutter test`
  green.

---

## Step 1 — ⏳ Create and verify a Google Play developer account

1. Go to the Google Play Console and register as a **developer** (one-time **$25
   USD** fee).
2. Choose a **personal** or **organization** account. **Note:** organization
   accounts are exempt from the closed-testing gate in Step 7; personal accounts
   are not.
3. Complete **identity verification** (and, for orgs, the D-U-N-S/verification
   flow). **This can take several days** — start it now.

---

## Step 2 — Generate an upload keystore and set up signing

### 2a. Generate the upload key (run once, locally)

```bash
keytool -genkey -v -keystore upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Answer the prompts; remember the **store password**, **key password**, and the
alias (`upload`). **Back this file up privately** — losing it means you can't
ship updates signed with the same upload key (recoverable via Play support, but
painful).

**Play App Signing:** Google holds the real *app signing key*; the key above is
your *upload key*. You sign uploads with the upload key, Google re-signs with the
app signing key for distribution. Enroll in Play App Signing on first upload
(it's the default for new apps).

### 2b. Keep secrets OUT of git

`android/key.properties` and `**/*.jks` are already gitignored (the committed
`android/app/debug.keystore` is intentionally the non-secret debug key). **Never
commit your upload keystore or its passwords.**

### 2c. Option A — sign locally

Create `android/key.properties` (gitignored):

```properties
storeFile=/absolute/path/to/upload-keystore.jks
storePassword=YOUR_STORE_PASSWORD
keyAlias=upload
keyPassword=YOUR_KEY_PASSWORD
```

`android/app/build.gradle.kts` already wires release signing from this file when
present (and falls back to debug signing when absent).

### 2d. Option B — let CI sign (recommended for reproducible builds)

Add these **repository secrets** (GitHub → Settings → Secrets and variables →
Actions):

| Secret | Value |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | `base64 -w0 upload-keystore.jks` (paste output) |
| `ANDROID_KEYSTORE_PASSWORD` | store password |
| `ANDROID_KEY_ALIAS` | `upload` |
| `ANDROID_KEY_PASSWORD` | key password |

`.github/workflows/build.yml` decodes these into `android/key.properties` at
build time when present.

---

## Step 3 — Build the release App Bundle (.aab)

### Locally

```bash
flutter build appbundle --release
# Output: build/app/outputs/bundle/release/app-release.aab
```

### Via CI (push a tag)

`build.yml` builds the `.aab` on every push and uploads it as the
`dyslexic-reader-aab` artifact; pushing a `v*` tag also attaches the APK + AAB to
a GitHub Release. (For automatic upload to Play, see "Automated deployment (CD)"
below.)

Google Play accepts **only** the `.aab`, not the APK. The APK is for sideloading
and quick testing.

---

## Step 4 — ⏳ Host the privacy policy and link it

Play **requires a publicly reachable privacy policy URL**.

1. Publish `docs/PRIVACY_POLICY.md` at a public URL. Free option — **GitHub
   Pages**: repo → Settings → Pages → enable for the `main` branch `/docs`
   folder (or a `gh-pages` branch). You'll get a URL like
   `https://<user>.github.io/dyslexic-reader/PRIVACY_POLICY`.
2. Update **`kPrivacyPolicyUrl`** in `lib/app/app_info.dart` to that final hosted
   URL and rebuild, so the in-app link matches. The current repository URL is a
   placeholder/action item, not a final Play Console privacy-policy URL.
3. Paste the URL into Play Console → **Policy → App content → Privacy policy**.

---

## Step 5 — Create the app and fill the store listing

1. Play Console → **Create app**. Name "Dyslexic Reader", app, free, declare it
   complies with policies.
2. **Main store listing:** paste title, short and full descriptions from
   `docs/STORE_LISTING.md`.
3. **Graphics:** upload `docs/store/play_icon_512.png` (app icon) and
   `docs/store/feature_graphic_1024x500.png` (feature graphic).
4. **Screenshots (required, ≥ 2 phone):** capture on a device/emulator. With the
   app running:
   ```bash
   adb exec-out screencap -p > screenshot1.png
   ```
   Recommended size **1080×1920**. Suggested shots: library, reader with
   spacing, theme picker, reading ruler, read-aloud with highlighting, settings.

---

## Step 6 — Complete the "App content" declarations

In Play Console → **Policy → App content**:

- **Privacy policy:** the URL from Step 4.
- **Data Safety:** fill from `docs/STORE_LISTING.md` §7 (no data collected, no
  data shared, processed on-device; explain the INTERNET permission).
- **Content rating:** complete the IARC questionnaire (expected **Everyone**;
  declare user-provided documents — see `docs/STORE_LISTING.md` §6).
- **Target audience:** teens/adults — **not** children (avoids the Families
  Policy program).
- **Ads:** declare **no ads**.
- **Government apps / financial features / health:** No.

---

## Step 7 — ⏳ New-account closed testing requirement (the big one)

Personal developer accounts created after **13 Nov 2023** must run **closed
testing with at least 12 testers opted in for 14 continuous days** before you can
apply for production access. This is **calendar time** no amount of engineering
shortens — start it as soon as you have a signable build.

### Set up the closed testing track

1. Play Console → **Test and release → Testing → Closed testing → Create track**.
2. Upload the `.aab` (or let CD push to it — see below).
3. Create an **email list** of **≥ 12 testers** (or a Google Group) and add them
   to the track. Each tester must **opt in** via the testing link and install the
   app.
4. Keep ≥ 12 testers enrolled for **14 continuous days**, then **apply for
   production access**.

### Run internal testing in parallel (no 14-day wait)

Use the **Internal testing** track (up to 100 testers, no waiting period) for
fast iteration while the 14-day closed test runs.

---

## Step 8 — Roll out to production

1. Once you **qualify** (Step 7) and **apply for production access**, Google
   reviews the request.
2. Create a **Production** release: Console → **Test and release → Production →
   Create new release**, upload the `.aab`, add the "What's new" notes from
   `docs/STORE_LISTING.md` §4.
3. **Review times:** initial app reviews for new accounts can take **a few days
   up to ~7 days** (sometimes longer); plan for it.
4. **Staged rollout (recommended):** start at e.g. **10–20%** of users, watch the
   Android vitals / crash rate / reviews, then increase to 50% → 100%. You can
   **halt** a rollout if something looks wrong.

---

## Automated deployment (CD) — publish on merge to `release`

`.github/workflows/release.yml` publishes a signed App Bundle to Google Play
whenever you **push or merge to the `release` branch** (and via manual
**Run workflow**, where you choose the track). It analyzes, tests, builds a
signed `.aab` with an auto-incrementing versionCode, and uploads it with the
release notes in `distribution/whatsnew/`. It **only uploads when the secrets
below exist** — otherwise it fails fast with a clear message — so it's safe to
have committed before your Play account is ready.

> ⚠️ **Google requires the first upload to be manual.** The Play Developer API
> will not accept a bundle until that package has had **at least one `.aab`
> uploaded by hand** in the Console (do Steps 5 + 7/8 once manually). After that,
> CD takes over.

**One-time setup**

1. **Signing secrets** — already covered in Step 2d (`ANDROID_KEYSTORE_BASE64`,
   `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`).
   CD reuses them to sign with your **upload** key.
2. **Play service account** — in **Google Cloud Console** create a service
   account, then **Play Console → Users and permissions → Invite user**, add the
   service-account email, and grant it release permission. Enable the **Google
   Play Android Developer API**. Create a **JSON key** for the account.
3. **`PLAY_SERVICE_ACCOUNT_JSON`** — paste the full JSON key as a repository
   secret.
4. **Optional repo variables** (Settings → Secrets and variables → Actions →
   *Variables*):
   - `PLAY_TRACK` — default track for `release`-branch pushes (`internal`,
     `alpha`, `beta`, `production`). Defaults to **`internal`**.
   - `VERSION_CODE_OFFSET` — added to the run number to form the versionCode.
     Bump it if you ever upload a higher code by hand (the code must strictly
     exceed the highest already on the track).

**How it runs**

| Trigger | Track |
|---|---|
| push / merge to `release` | `vars.PLAY_TRACK` (else `internal`) |
| Actions → Run workflow (dispatch) | the track you pick |

- versionCode = `VERSION_CODE_OFFSET + github.run_number` (monotonic);
  versionName comes from `pubspec.yaml`.
- `status: completed`. For a **staged** production rollout, change `status` in
  `release.yml` to `inProgress` and add `userFraction` (e.g. `0.2`).
- Promote internal → production from the Console, or dispatch with
  `track: production` once you've **passed the closed-testing gate** (Step 7).

**Recommended flow:** publish to `internal` from `release` for everyday builds;
do production rollouts deliberately (Console or a `production` dispatch).

---

## Step 9 — Pre-launch checklist

Tick every box before submitting to production.

- [ ] **Developer account verified** (identity check cleared) — Step 1
- [ ] **Closed testing complete:** 12+ testers opted in for 14 continuous days; production access granted — Step 7
- [ ] **App name correct:** "Dyslexic Reader" in listing, manifest `@string/app_name`, and `kAppName`
- [ ] **Version set:** versionName `1.0.0`, versionCode `1` (`version: 1.0.0+1` in `pubspec.yaml`); `kAppVersion` matches
- [ ] **targetSdk ≥ 35** — already 36 via the Flutter SDK ✔
- [ ] **`.aab` is upload-signed** (release signing config used, not debug) — Step 2/3
- [ ] **`.aab` built from a clean release build** and downloaded from CI/local — Step 3
- [ ] **Upload keystore backed up** safely and privately; passwords stored in a password manager
- [ ] **No secrets in git** — `key.properties` and `*.jks` confirmed gitignored
- [ ] **Tested on a real Android device** (not just emulator): open a PDF, .docx, text, and paste; OCR a scanned PDF; read-aloud with highlighting; reading ruler; themes; bookmarks/notes
- [ ] **Open-with / share-to verified** from another app (PDF, .docx, text intents)
- [ ] **All launcher icon densities present** (mipmap `ic_launcher` / `ic_launcher_round` render correctly on device)
- [ ] **Privacy policy reachable** at the hosted URL (opened in a browser; not the repository placeholder) — Step 4
- [ ] **`kPrivacyPolicyUrl` updated** to the live URL and the `.aab` rebuilt — Step 4
- [ ] **Store listing filled:** title (15/30), short desc (≤80), full desc (≤4000) — `docs/STORE_LISTING.md`
- [ ] **Icon (512) + feature graphic (1024×500) uploaded** from `docs/store/`
- [ ] **≥ 2 phone screenshots uploaded** (recommend 4–6, 1080×1920) — Step 5
- [ ] **App content declarations complete:** Data Safety (no data), content rating (Everyone), target audience (teens/adults — not children), ads = none, government = no, financial = no, health = no
- [ ] **Category set to Education** (Books & Reference is the fallback) — `docs/STORE_LISTING.md` §5
- [ ] **Free price confirmed** (cannot change free→paid later)
- [ ] **Release notes** entered for v1.0.0
- [ ] **Staged rollout** chosen for the production release — Step 8
- [ ] **(If using CD)** first `.aab` uploaded manually once; `PLAY_SERVICE_ACCOUNT_JSON` + signing secrets set; service account invited in Play Console — see "Automated deployment (CD)"
