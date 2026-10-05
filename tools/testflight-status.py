#!/usr/bin/env python3
"""Confirm the exact uploaded build is processed and available in TestFlight.
Credentials stay in memory; only build identity and availability are recorded.
"""
import base64
import json
import os
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives.asymmetric.utils import decode_dss_signature


def b64(value):
    return base64.urlsafe_b64encode(value).rstrip(b"=").decode()


def token():
    now = int(time.time())
    header = b64(json.dumps({"alg": "ES256", "kid": os.environ["ASC_KEY_ID"], "typ": "JWT"}).encode())
    body = b64(json.dumps({"iss": os.environ["ASC_ISSUER_ID"], "iat": now, "exp": now + 600, "aud": "appstoreconnect-v1"}).encode())
    key = serialization.load_pem_private_key(os.environ["ASC_PRIVATE_KEY"].encode(), None)
    data = (header + "." + body).encode()
    r, s = decode_dss_signature(key.sign(data, ec.ECDSA(hashes.SHA256())))
    return data.decode() + "." + b64(r.to_bytes(32, "big") + s.to_bytes(32, "big"))


def api(path, params=None, body=None):
    url = "https://api.appstoreconnect.apple.com/v1/" + path
    if params:
        url += "?" + urllib.parse.urlencode(params)
    request = urllib.request.Request(url, headers={"Authorization": "Bearer " + token(), "Content-Type": "application/json"}, data=json.dumps(body).encode() if body else None)
    try:
        with urllib.request.urlopen(request, timeout=45) as response:
            content = response.read()
            return json.loads(content) if content else {}
    except urllib.error.HTTPError as error:
        details = json.loads(error.read()).get("errors", [])
        raise RuntimeError("Apple API %s: %s" % (error.code, "; ".join(e.get("detail", e.get("title", "")) for e in details))) from None


def main():
    apps = api("apps", {"filter[bundleId]": os.environ["BUNDLE_ID"]})["data"]
    if len(apps) != 1:
        raise RuntimeError("The bundle must identify exactly one Apple app")
    app_id = apps[0]["id"]
    deadline = time.monotonic() + int(os.environ.get("TESTFLIGHT_WAIT_SECONDS", "1200"))
    last = None
    assigned = False
    while time.monotonic() < deadline:
        builds = api("builds", {"filter[app]": app_id, "filter[version]": os.environ["BUILD_NUMBER"], "include": "preReleaseVersion,buildBetaDetail,betaGroups"})
        if builds["data"]:
            build = builds["data"][0]
            included = {item["id"]: item for item in builds.get("included", [])}
            release_id = build["relationships"]["preReleaseVersion"]["data"]["id"]
            version = included[release_id]["attributes"]["version"]
            if version != os.environ["APP_VERSION"]:
                raise RuntimeError("Uploaded build version does not match this release")
            detail = {"internalBuildState": "PROCESSING", "externalBuildState": "PROCESSING"}
            if build["attributes"]["processingState"] == "VALID":
                detail = api("builds/" + build["id"] + "/buildBetaDetail")["data"]["attributes"]
            state = {"app_id": app_id, "build_id": build["id"], "version": version, "build_number": build["attributes"]["version"], "processing": build["attributes"]["processingState"], "internal": detail["internalBuildState"], "external": detail["externalBuildState"]}
            if state != last:
                print("TestFlight status: " + json.dumps(state), flush=True)
                last = state
            if state["processing"] in ("FAILED", "INVALID"):
                raise RuntimeError("Apple processing rejected the build")
            if state["processing"] == "VALID" and state["internal"] in ("IN_BETA_TESTING", "READY_FOR_BETA_TESTING"):
                groups = api("builds/" + build["id"] + "/betaGroups")["data"]
                if not groups and not assigned:
                    assigned = True
                    for group in api("betaGroups", {"filter[app]": app_id, "filter[isInternalGroup]": "true"})["data"]:
                        if not group["attributes"].get("hasAccessToAllBuilds", False):
                            api("betaGroups/" + group["id"] + "/relationships/builds", body={"data": [{"type": "builds", "id": build["id"]}]})
                    groups = api("builds/" + build["id"] + "/betaGroups")["data"]
                state["beta_groups"] = [{"id": group["id"], "name": group["attributes"]["name"]} for group in groups]
                output = Path("build/ios/testflight-status.json")
                output.parent.mkdir(parents=True, exist_ok=True)
                output.write_text(json.dumps(state, indent=2), encoding="utf-8")
                print("TestFlight build is processed and ready: " + json.dumps(state), flush=True)
                return
        else:
            print("TestFlight: waiting for the uploaded build to appear", flush=True)
        time.sleep(30)
    raise RuntimeError("Upload accepted, but Apple has not made this build ready within the verification window")


if __name__ == "__main__":
    main()
