import json
import os
from pathlib import Path

names = {
    "product_id": "EOS_PRODUCT_ID",
    "sandbox_id": "EOS_SANDBOX_ID",
    "deployment_id": "EOS_DEPLOYMENT_ID",
    "client_id": "EOS_CLIENT_ID",
    "client_secret": "EOS_CLIENT_SECRET",
}
missing = [env for env in names.values() if not os.environ.get(env)]
if missing:
    if os.environ.get("EOS_ALLOW_PLACEHOLDER", "").lower() != "true":
        raise SystemExit("Missing EOS build secrets: " + ", ".join(missing))
    # Native compile/test builds do not contact EOS. Keep a deliberately
    # invalid, recognizable credential set so public CI can verify Android and
    # iOS packaging before an Epic product exists. Store workflows never set
    # EOS_ALLOW_PLACEHOLDER and therefore remain fail-closed.
    for env in missing:
        os.environ[env] = "ci-placeholder-" + env.lower().replace("eos_", "")
    print("::warning::Using non-production EOS placeholders; online rooms will not work in this artifact")

payload = {key: os.environ[env] for key, env in names.items()}
payload.update(product_name="SIDE / SKY", product_version=os.environ.get("EOS_BUILD_VERSION", "dev"))
Path("eos_credentials.json").write_text(json.dumps(payload, separators=(",", ":")), encoding="utf-8")
print("Wrote eos_credentials.json with least-privilege client credentials")
