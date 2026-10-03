# Repository workflow

`555734/Kiki-public` is the active repository. Its `main` branch is the development line. A `release` branch records the exact source revision sent for store review; it advances only when a new version is submitted. A successful CI build or an upload to App Store Connect is not, by itself, proof of review submission.

Work on `main`. Every relevant push runs Android and iOS test builds. Download test APKs and the unsigned IPA from the successful Actions run's artifacts. Test builds no longer create GitHub Releases or tags.

Store builds are started manually from the intended source revision. Record the Android version code, iOS build number, store submission date, and commit SHA before advancing `release`. If the platforms are submitted at different revisions, use immutable `submitted/android/<version-code>` and `submitted/ios/<build-number>` tags so neither submission is lost when `release` advances.

The former public branch tips are preserved under the annotated tag `archive/branches-2026-10-03`. Its tagged commit has the old branch tips as parents and the same file tree as the previous `main`; it is a history archive, not a merge into the game. `555734/Kiki` retains earlier private history and its open PR until that work is resolved. Local worktrees with uncommitted changes are left intact.

Older `build-*` and `ios-build-*` GitHub Releases remain available as historical downloads. They are not evidence of store submission.
