#!/usr/bin/env python3
"""Resume App Review after an accepted upload, without rebuilding or reuploading."""
import importlib.util
import json
import os
import re
import subprocess
import sys
import time
from pathlib import Path

spec = importlib.util.spec_from_file_location("apple", Path(__file__).with_name("testflight-status.py"))
apple = importlib.util.module_from_spec(spec)
spec.loader.exec_module(apple)


def main():
    version = re.search(r'^config/version="([^"]+)"$', Path("project.godot").read_text(encoding="utf-8"), re.M).group(1)
    number = os.environ["BUILD_NUMBER"]
    if not re.fullmatch(r"[0-9]+(?:\.[0-9]+)*", number):
        raise RuntimeError("Expected an exact numeric CFBundleVersion")
    apps = apple.api("apps", {"filter[bundleId]": "com.sasakiful.sidesky"})["data"]
    if len(apps) != 1:
        raise RuntimeError("Expected exactly one matching app")
    app_id = apps[0]["id"]
    response = apple.api("builds", {"filter[app]": app_id, "filter[version]": number, "include": "preReleaseVersion"})
    if len(response["data"]) != 1:
        raise RuntimeError("The exact uploaded build must exist before resuming submission")
    build = response["data"][0]
    releases = {item["id"]: item for item in response.get("included", [])}
    release_id = build["relationships"]["preReleaseVersion"]["data"]["id"]
    if releases[release_id]["attributes"]["version"] != version or build["attributes"]["processingState"] != "VALID":
        raise RuntimeError("Refusing a build with a different marketing version or incomplete processing")

    versions = apple.api("apps/" + app_id + "/appStoreVersions", {"filter[platform]": "IOS", "limit": 50})["data"]
    selected = [v for v in versions if v["attributes"]["versionString"] == version]
    editable_states = ("PREPARE_FOR_SUBMISSION", "READY_FOR_REVIEW", "DEVELOPER_REJECTED", "REJECTED", "METADATA_REJECTED", "WAITING_FOR_REVIEW", "IN_REVIEW")
    if any(v["attributes"]["versionString"] != version and v["attributes"]["appStoreState"] in editable_states for v in versions):
        raise RuntimeError("Another version is pending; refusing to replace or cancel it")
    submitted_states = ("WAITING_FOR_REVIEW", "IN_REVIEW", "PENDING_DEVELOPER_RELEASE", "PENDING_APPLE_RELEASE", "READY_FOR_SALE")
    already_submitted = len(selected) == 1 and selected[0]["attributes"]["appStoreState"] in submitted_states
    listing = Path("docs/store-listing.md").read_text(encoding="utf-8")
    description = re.search(r"\*\*詳しい説明（両ストア共通）\*\*\s*```\n(.*?)\n```", listing, re.S).group(1)
    notes = subprocess.check_output([sys.executable, "tools/release-notes.py", "ja"],
        encoding="utf-8", env={**os.environ, "PYTHONIOENCODING": "utf-8"}).strip()
    if not notes:
        raise RuntimeError("This version must have release notes")
    if not already_submitted:
        os.environ["APP_STORE_CONNECT_KEY_IDENTIFIER"] = os.environ["ASC_KEY_ID"]
        os.environ["APP_STORE_CONNECT_ISSUER_ID"] = os.environ["ASC_ISSUER_ID"]
        os.environ["APP_STORE_CONNECT_PRIVATE_KEY"] = os.environ["ASC_PRIVATE_KEY"]
        subprocess.run([
            "app-store-connect", "builds", "submit-to-app-store", build["id"],
            "--version-string", version, "--release-type", "AFTER_APPROVAL",
            "--max-build-processing-wait", "0", "--locale", "ja",
            "--description", description, "--whats-new", notes,
        ], check=True)

    for _ in range(12):
        versions = apple.api("apps/" + app_id + "/appStoreVersions", {"filter[platform]": "IOS", "limit": 50})["data"]
        selected = [v for v in versions if v["attributes"]["versionString"] == version]
        if len(selected) == 1 and selected[0]["attributes"]["appStoreState"] in submitted_states:
            break
        time.sleep(10)
    if len(selected) != 1 or selected[0]["attributes"]["appStoreState"] not in submitted_states:
        raise RuntimeError("Apple has not confirmed the version was submitted for review")
    store_version = selected[0]
    attached = apple.api("appStoreVersions/" + store_version["id"] + "/build")["data"]
    if attached["id"] != build["id"]:
        raise RuntimeError("The submitted version is attached to a different build")
    localizations = apple.api("appStoreVersions/" + store_version["id"] + "/appStoreVersionLocalizations")["data"]
    japanese = [item for item in localizations if item["attributes"]["locale"] in ("ja", "ja-JP")]
    if len(japanese) != 1 or japanese[0]["attributes"]["description"] != description or japanese[0]["attributes"]["whatsNew"].strip() != notes:
        raise RuntimeError("The submitted Japanese listing does not match this source version")
    state = {"checked_at_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "app_id": app_id, "version": version, "build_number": number, "build_id": build["id"],
        "store_version_id": store_version["id"], "state": store_version["attributes"]["appStoreState"],
        "processing": build["attributes"]["processingState"], "listing_verified": True}
    output = Path("build/ios/review-status.json")
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(state, indent=2), encoding="utf-8")
    print("Verified App Review submission: " + json.dumps(state), flush=True)


if __name__ == "__main__":
    main()
