#!/usr/bin/env python3
"""Submit AI Shogi Kento's uploaded build for App Review. Release stays MANUAL; nothing is published."""
import base64, json, os, re, sys, time, urllib.error, urllib.parse, urllib.request
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives.asymmetric.utils import decode_dss_signature

BUNDLE = "com.presentsoft.shogi3minutes"
NOTES = """・対局の手触りを改善：駒の移動アニメーション、効果音と振動、駒取り・成り・王手の演出、盤上での成り選択、対局開始と終局の演出
・書体と配色を刷新し、画面を見やすく整理
・オンライン対戦の画面を一新（ランダム対戦を中心に、マッチング中は対局時計で待ち時間を表示）
・相手が8秒見つからない時は、レートの近いボット（10段階・ボットと明示）と対局できるように"""
EDITABLE = ("PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED", "METADATA_REJECTED", "INVALID_BINARY")
BUSY = ("WAITING_FOR_REVIEW", "IN_REVIEW", "PENDING_DEVELOPER_RELEASE", "PENDING_APPLE_RELEASE", "PROCESSING_FOR_APP_STORE", "WAITING_FOR_EXPORT_COMPLIANCE")
SUBMITTED = ("WAITING_FOR_REVIEW", "IN_REVIEW")


def b64(v):
    return base64.urlsafe_b64encode(v).rstrip(b"=").decode()


def token():
    now = int(time.time())
    head = b64(json.dumps({"alg": "ES256", "kid": os.environ["ASC_KEY_ID"], "typ": "JWT"}).encode())
    body = b64(json.dumps({"iss": os.environ["ASC_ISSUER_ID"], "iat": now, "exp": now + 600, "aud": "appstoreconnect-v1"}).encode())
    key = serialization.load_pem_private_key(os.environ["ASC_PRIVATE_KEY"].encode(), None)
    data = (head + "." + body).encode()
    r, s = decode_dss_signature(key.sign(data, ec.ECDSA(hashes.SHA256())))
    return data.decode() + "." + b64(r.to_bytes(32, "big") + s.to_bytes(32, "big"))


def api(path, params=None, body=None, method=None):
    url = "https://api.appstoreconnect.apple.com/v1/" + path
    if params:
        url += "?" + urllib.parse.urlencode(params)
    req = urllib.request.Request(url, method=method or ("POST" if body else "GET"),
        headers={"Authorization": "Bearer " + token(), "Content-Type": "application/json"},
        data=json.dumps(body).encode() if body else None)
    try:
        with urllib.request.urlopen(req, timeout=60) as res:
            content = res.read()
            return json.loads(content) if content else {}
    except urllib.error.HTTPError as e:
        raw = e.read()
        try:
            errs = json.loads(raw).get("errors", [])
            msg = "; ".join("%s %s" % (x.get("code", ""), x.get("detail", x.get("title", ""))) for x in errs)
        except ValueError:
            msg = raw[:300].decode(errors="replace")
        raise RuntimeError("Apple API %s %s %s: %s" % (req.get_method(), path, e.code, msg)) from None


def log(*a):
    print(*a, flush=True)


def versions(app_id):
    return api("apps/" + app_id + "/appStoreVersions", {"filter[platform]": "IOS", "limit": 50})["data"]


def main():
    version, number = os.environ["SHOGI_VERSION"], os.environ["BUILD_NUMBER"]
    if not re.fullmatch(r"\d+\.\d+\.\d+", version) or not re.fullmatch(r"\d+", number):
        raise RuntimeError("bad version/build input")
    apps = api("apps", {"filter[bundleId]": BUNDLE})["data"]
    if len(apps) != 1:
        raise RuntimeError("expected exactly one app")
    app_id = apps[0]["id"]
    res = api("builds", {"filter[app]": app_id, "filter[version]": number, "include": "preReleaseVersion"})
    if len(res["data"]) != 1:
        raise RuntimeError("build %s not found" % number)
    build = res["data"][0]
    pre = {i["id"]: i for i in res.get("included", [])}[build["relationships"]["preReleaseVersion"]["data"]["id"]]
    log("build", number, "marketing", pre["attributes"]["version"], "processing", build["attributes"]["processingState"],
        "encryption", build["attributes"].get("usesNonExemptEncryption"))
    if pre["attributes"]["version"] != version or build["attributes"]["processingState"] != "VALID":
        raise RuntimeError("build is not a processed %s" % version)
    if build["attributes"].get("usesNonExemptEncryption") is None:
        api("builds/" + build["id"], body={"data": {"type": "builds", "id": build["id"], "attributes": {"usesNonExemptEncryption": False}}}, method="PATCH")
        log("export compliance: usesNonExemptEncryption=false (matches Info.plist)")

    all_v = versions(app_id)
    for v in all_v:
        a = v["attributes"]
        log("version", a["versionString"], a["appStoreState"], a.get("releaseType"))
    target = [v for v in all_v if v["attributes"]["versionString"] == version]
    if target and target[0]["attributes"]["appStoreState"] in SUBMITTED + ("PENDING_DEVELOPER_RELEASE", "PENDING_APPLE_RELEASE", "READY_FOR_SALE"):
        log("already submitted:", target[0]["attributes"]["appStoreState"])
        store = target[0]
    else:
        busy = [v for v in all_v if v["attributes"]["versionString"] != version and v["attributes"]["appStoreState"] in BUSY]
        if busy:
            raise RuntimeError("another version is in flight (%s %s); not cancelling it" % (busy[0]["attributes"]["versionString"], busy[0]["attributes"]["appStoreState"]))
        if target:
            store = target[0]
        else:
            other = [v for v in all_v if v["attributes"]["appStoreState"] in EDITABLE]
            if other:
                store = other[0]
                api("appStoreVersions/" + store["id"], body={"data": {"type": "appStoreVersions", "id": store["id"], "attributes": {"versionString": version}}}, method="PATCH")
                log("renamed editable version", store["attributes"]["versionString"], "->", version)
            else:
                store = api("appStoreVersions", body={"data": {"type": "appStoreVersions",
                    "attributes": {"platform": "IOS", "versionString": version, "releaseType": "MANUAL"},
                    "relationships": {"app": {"data": {"type": "apps", "id": app_id}}}}})["data"]
                log("created version", version)
        sid = store["id"]
        api("appStoreVersions/" + sid, body={"data": {"type": "appStoreVersions", "id": sid, "attributes": {"releaseType": "MANUAL"}}}, method="PATCH")
        api("appStoreVersions/" + sid + "/relationships/build", body={"data": {"type": "builds", "id": build["id"]}}, method="PATCH")
        locs = api("appStoreVersions/" + sid + "/appStoreVersionLocalizations")["data"]
        ja = [l for l in locs if l["attributes"]["locale"] in ("ja", "ja-JP")]
        log("localizations", [l["attributes"]["locale"] for l in locs])
        if len(ja) != 1:
            raise RuntimeError("expected one Japanese localization copied from the previous version")
        for l in locs:
            api("appStoreVersionLocalizations/" + l["id"], body={"data": {"type": "appStoreVersionLocalizations", "id": l["id"], "attributes": {"whatsNew": NOTES}}}, method="PATCH")
        open_subs = api("reviewSubmissions", {"filter[app]": app_id, "filter[platform]": "IOS",
            "filter[state]": "READY_FOR_REVIEW,UNRESOLVED_ISSUES,WAITING_FOR_REVIEW,IN_REVIEW", "include": "items"})
        for s in open_subs["data"]:
            log("open submission", s["id"], s["attributes"]["state"])
        if any(s["attributes"]["state"] in ("WAITING_FOR_REVIEW", "IN_REVIEW") for s in open_subs["data"]):
            raise RuntimeError("a review submission is already in review; not touching it")
        ready = [s for s in open_subs["data"] if s["attributes"]["state"] in ("READY_FOR_REVIEW", "UNRESOLVED_ISSUES")]
        sub = ready[0] if ready else api("reviewSubmissions", body={"data": {"type": "reviewSubmissions",
            "attributes": {"platform": "IOS"}, "relationships": {"app": {"data": {"type": "apps", "id": app_id}}}}})["data"]
        items = api("reviewSubmissions/" + sub["id"] + "/items", {"include": "appStoreVersion"})["data"]
        has = any((i["relationships"].get("appStoreVersion", {}).get("data") or {}).get("id") == sid for i in items)
        log("submission", sub["id"], "items", len(items), "has version", has)
        if not has:
            api("reviewSubmissionItems", body={"data": {"type": "reviewSubmissionItems",
                "relationships": {"reviewSubmission": {"data": {"type": "reviewSubmissions", "id": sub["id"]}},
                                  "appStoreVersion": {"data": {"type": "appStoreVersions", "id": sid}}}}})
        api("reviewSubmissions/" + sub["id"], body={"data": {"type": "reviewSubmissions", "id": sub["id"], "attributes": {"submitted": True}}}, method="PATCH")
        log("submitted review submission", sub["id"])

    for _ in range(18):
        store = [v for v in versions(app_id) if v["attributes"]["versionString"] == version][0]
        if store["attributes"]["appStoreState"] in SUBMITTED + ("PENDING_DEVELOPER_RELEASE",):
            break
        time.sleep(10)
    a = store["attributes"]
    attached = api("appStoreVersions/" + store["id"] + "/build")["data"]
    ja = [l for l in api("appStoreVersions/" + store["id"] + "/appStoreVersionLocalizations")["data"] if l["attributes"]["locale"] in ("ja", "ja-JP")]
    result = {"version": version, "build": number, "state": a["appStoreState"], "releaseType": a.get("releaseType"),
              "build_attached": attached and attached["id"] == build["id"], "whatsNew_ok": bool(ja) and (ja[0]["attributes"]["whatsNew"] or "").strip() == NOTES}
    log("RESULT", json.dumps(result, ensure_ascii=False))
    if a.get("releaseType") != "MANUAL":
        api("appStoreVersions/" + store["id"], body={"data": {"type": "appStoreVersions", "id": store["id"], "attributes": {"releaseType": "MANUAL"}}}, method="PATCH")
        log("releaseType restored to MANUAL")
    if a["appStoreState"] not in SUBMITTED + ("PENDING_DEVELOPER_RELEASE",) or not result["build_attached"]:
        sys.exit("not confirmed as submitted")


if __name__ == "__main__":
    main()
