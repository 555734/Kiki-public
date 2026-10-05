#!/usr/bin/env python3
"""Read store build identities without publishing or committing an edit.

Only non-secret store state is written. The temporary Google edit is deleted.
"""
import importlib.util
import json
import os
import re
import time
import urllib.parse
import urllib.request
from pathlib import Path
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import padding

spec = importlib.util.spec_from_file_location("testflight", Path(__file__).with_name("testflight-status.py"))
apple = importlib.util.module_from_spec(spec)
spec.loader.exec_module(apple)


def request(url, bearer=None, method="GET", body=None):
    headers = {"Authorization": "Bearer " + bearer} if bearer else {}
    if body is not None:
        headers["Content-Type"] = "application/json"
    req = urllib.request.Request(url, data=json.dumps(body).encode() if body is not None else None,
                                 headers=headers, method=method)
    with urllib.request.urlopen(req, timeout=45) as response:
        data = response.read()
        return json.loads(data) if data else {}


def play_status():
    account = json.loads(os.environ["PLAY_SERVICE_ACCOUNT_JSON"])
    now = int(time.time())
    header = apple.b64(json.dumps({"alg": "RS256", "typ": "JWT"}).encode())
    claims = apple.b64(json.dumps({"iss": account["client_email"], "iat": now, "exp": now + 600,
        "aud": "https://oauth2.googleapis.com/token",
        "scope": "https://www.googleapis.com/auth/androidpublisher"}).encode())
    data = (header + "." + claims).encode()
    key = serialization.load_pem_private_key(account["private_key"].encode(), None)
    jwt = data.decode() + "." + apple.b64(key.sign(data, padding.PKCS1v15(), hashes.SHA256()))
    form = urllib.parse.urlencode({"grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer", "assertion": jwt}).encode()
    with urllib.request.urlopen(urllib.request.Request("https://oauth2.googleapis.com/token", data=form), timeout=45) as response:
        bearer = json.load(response)["access_token"]
    package = "com.sasakiful.melos"
    base = "https://androidpublisher.googleapis.com/androidpublisher/v3/applications/" + package + "/edits"
    edit = request(base, bearer, "POST", {})["id"]
    try:
        tracks = request(base + "/" + edit + "/tracks", bearer).get("tracks", [])
        bundles = request(base + "/" + edit + "/bundles", bearer).get("bundles", [])
        apks = request(base + "/" + edit + "/apks", bearer).get("apks", [])
        codes = [int(b["versionCode"]) for b in bundles + apks]
        codes += [int(c) for t in tracks for r in t.get("releases", []) for c in r.get("versionCodes", [])]
        return {"package": package, "max_version_code": max(codes, default=0), "tracks": tracks}
    finally:
        request(base + "/" + edit, bearer, "DELETE")


def apple_status():
    apps = apple.api("apps", {"filter[bundleId]": "com.sasakiful.sidesky"})["data"]
    if len(apps) != 1:
        raise RuntimeError("Expected one Apple app")
    app_id = apps[0]["id"]
    versions = apple.api("apps/" + app_id + "/appStoreVersions", {"filter[platform]": "IOS", "limit": 50})["data"]
    if os.environ.get("UPDATE_APPLE_DESCRIPTION") == "true":
        version = re.search(r'^config/version="([^"]+)"$', Path("project.godot").read_text(encoding="utf-8"), re.M).group(1)
        matches = [v for v in versions if v["attributes"]["versionString"] == version]
        if len(matches) != 1:
            raise RuntimeError("The selected source version must already exist in App Store Connect")
        selected = matches[0]
        if selected["attributes"]["appStoreState"] not in ("PREPARE_FOR_SUBMISSION", "READY_FOR_REVIEW", "WAITING_FOR_REVIEW"):
            raise RuntimeError("Refusing to modify a published or actively reviewed version")
        listing = Path("docs/store-listing.md").read_text(encoding="utf-8")
        description = re.search(r"\*\*詳しい説明（両ストア共通）\*\*\s*```\n(.*?)\n```", listing, re.S).group(1)
        localizations = apple.api("appStoreVersions/" + selected["id"] + "/appStoreVersionLocalizations")["data"]
        japanese = [item for item in localizations if item["attributes"]["locale"] in ("ja", "ja-JP")]
        if len(japanese) != 1:
            raise RuntimeError("Expected exactly one existing Japanese localization")
        localization = japanese[0]
        body = {"data": {"type": "appStoreVersionLocalizations", "id": localization["id"], "attributes": {"description": description}}}
        request("https://api.appstoreconnect.apple.com/v1/appStoreVersionLocalizations/" + localization["id"], apple.token(), "PATCH", body)
        confirmed = apple.api("appStoreVersionLocalizations/" + localization["id"])["data"]["attributes"]["description"]
        if confirmed != description:
            raise RuntimeError("Apple description readback did not match the selected source")
        print("Confirmed Japanese description for Apple version " + version)
    return {"app_id": app_id, "versions": [{"id": v["id"], "version": v["attributes"]["versionString"],
        "state": v["attributes"]["appStoreState"]} for v in versions]}


if __name__ == "__main__":
    result = {"checked_at_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())}
    errors = []
    for name, check in [("google_play", play_status), ("app_store", apple_status)]:
        try:
            result[name] = check()
        except Exception as error:
            # Avoid dumping request headers, JWTs, account JSON or private keys.
            result[name] = {"error": type(error).__name__, "status": getattr(error, "code", None)}
            errors.append(name)
    output = Path("build/store-status.json")
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(result, indent=2), encoding="utf-8")
    print(json.dumps(result, indent=2))
    if errors:
        raise SystemExit("Store reads failed: " + ", ".join(errors))
