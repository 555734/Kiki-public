# Android test signing

No Android private signing key is stored in this repository.

For local builds, `tools/build-android.sh` and `tools/build-android.ps1` use a
machine-local test keystore under the current user's profile. If it does not
exist yet, the build creates it automatically. Reusing the same local key means
new test APKs from that machine can normally install over older ones.

GitHub Actions is intentionally different: every workflow run creates a
throwaway key in the runner's temporary directory. The key is never committed,
cached, uploaded as an artifact, or reused by another run. As a consequence,
installing an APK from a different Actions run may require uninstalling the
previous test build first.

## Google Play

Neither local nor CI test keys are Google Play upload keys. Before any store
submission, create a dedicated release/upload key and keep it outside Git. Pass
it to the build through local environment variables or a CI secret store.

Example:

```bash
keytool -genkeypair -v -keystore release.keystore -alias upload \
  -keyalg RSA -keysize 2048 -validity 10000
```

Then build the store AAB with:

```bash
GODOT_ANDROID_KEYSTORE_RELEASE_PATH=/secure/path/release.keystore \
GODOT_ANDROID_KEYSTORE_RELEASE_USER=upload \
GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=... \
VERSION_CODE=24 VERSION_NAME=0.2.4 \
  tools/build-android-play.sh
```

The Play artifact is `build/android/side-sky-play.aab`. The Motorola-named APK
is a sideload test alias of the Vulkan APK and is never submitted separately.

Never commit `.keystore`, `.jks`, `.p8`, `.p12`, `.pem`, provisioning profiles,
service-account files, `.env` files, or other credentials. `.gitignore` blocks
these common forms, but a secret that was committed previously must still be
rotated/revoked and removed from public history.
