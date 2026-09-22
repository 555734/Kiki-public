"""Patch a freshly generated Godot Android Gradle template for EOS SDK init."""
from pathlib import Path
import os
import json

root = Path("android/build")
gradle = root / "build.gradle"
config = root / "config.gradle"
if not gradle.exists() or not config.exists():
    raise SystemExit("Install the Android build template before configuring EOSG")

client_id = os.environ.get("EOS_CLIENT_ID", "").strip()
if not client_id and Path("eos_credentials.json").exists():
    client_id = str(json.loads(Path("eos_credentials.json").read_text(encoding="utf-8")).get("client_id", "")).strip()
if not client_id:
    raise SystemExit("EOS_CLIENT_ID is required")

text = gradle.read_text(encoding="utf-8")
dependencies = [
    "implementation 'androidx.appcompat:appcompat:1.5.1'",
    "implementation 'androidx.constraintlayout:constraintlayout:2.1.4'",
    "implementation 'androidx.security:security-crypto:1.0.0'",
    "implementation 'androidx.browser:browser:1.4.0'",
    "implementation 'androidx.webkit:webkit:1.7.0'",
    "implementation files('../../addons/epic-online-services-godot/bin/android/eossdk-StaticSTDC-release.aar')",
]
missing_dependencies = [line for line in dependencies if line not in text]
if missing_dependencies:
    anchor = "dependencies {"
    if anchor not in text:
        raise SystemExit("Unknown Godot Android build.gradle: dependencies block missing")
    text = text.replace(
        anchor,
        anchor + "\n    // EOS Android SDK dependencies\n    " + "\n    ".join(missing_dependencies),
        1,
    )

scheme = 'resValue("string", "eos_login_protocol_scheme", "eos.' + client_id.lower() + '")'
if "eos_login_protocol_scheme" not in text:
    anchor = "defaultConfig {"
    if anchor not in text:
        raise SystemExit("Unknown Godot Android build.gradle: defaultConfig missing")
    text = text.replace(anchor, anchor + "\n        " + scheme, 1)
gradle.write_text(text, encoding="utf-8", newline="\n")

cfg = config.read_text(encoding="utf-8")
import re
cfg, count = re.subn(r"minSdk\s*:\s*\d+", "minSdk             : 24", cfg, count=1)
if count != 1:
    raise SystemExit("Unknown Godot config.gradle: minSdk missing")
config.write_text(cfg, encoding="utf-8", newline="\n")

activities = (
    list(root.glob("src/**/GodotApp.java"))
    + list(root.glob("src/**/GodotGame.java"))
    + list(root.glob("src/**/GodotApp.kt"))
    + list(root.glob("src/**/GodotGame.kt"))
)
if len(activities) != 1:
    raise SystemExit(f"Expected one Godot Android activity, found {len(activities)}")
activity = activities[0]
source = activity.read_text(encoding="utf-8")
if activity.suffix == ".java":
    if "com.epicgames.mobile.eossdk.EOSSDK" not in source:
        source = source.replace(
            "import org.godotengine.godot.GodotActivity;",
            "import org.godotengine.godot.GodotActivity;\nimport com.epicgames.mobile.eossdk.EOSSDK;",
        )
    if 'System.loadLibrary("EOSSDK")' not in source:
        class_pos = source.find(" extends GodotActivity")
        brace = source.find("{", class_pos)
        if brace < 0:
            raise SystemExit("Unknown Java Godot activity source")
        source = source[: brace + 1] + '\n    static { System.loadLibrary("EOSSDK"); }\n' + source[brace + 1 :]
    if "EOSSDK.init(getActivity())" not in source:
        marker = "super.onCreate(savedInstanceState);"
        if marker not in source:
            raise SystemExit("Unknown Java Godot activity onCreate")
        source = source.replace(marker, "EOSSDK.init(getActivity());\n        " + marker, 1)
else:
    if "com.epicgames.mobile.eossdk.EOSSDK" not in source:
        package_end = source.find("\n", source.find("package "))
        source = source[: package_end + 1] + "\nimport com.epicgames.mobile.eossdk.EOSSDK\n" + source[package_end + 1 :]
    if 'System.loadLibrary("EOSSDK")' not in source:
        class_match = re.search(r"class\s+Godot(?:App|Game)[^{]*\{", source)
        if class_match is None:
            raise SystemExit("Unknown Kotlin Godot activity source")
        insertion = '\n    companion object { init { System.loadLibrary("EOSSDK") } }\n'
        source = source[: class_match.end()] + insertion + source[class_match.end() :]
    if "EOSSDK.init(this)" not in source:
        marker = "super.onCreate(savedInstanceState)"
        if marker not in source:
            raise SystemExit("Unknown Kotlin Godot activity onCreate")
        source = source.replace(marker, "EOSSDK.init(this)\n        " + marker, 1)
activity.write_text(source, encoding="utf-8", newline="\n")
print(f"Configured EOSG Android template: {activity}")
