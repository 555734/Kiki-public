from pathlib import Path

path = Path("addons/epic-online-services-godot/heos/hauth.gd")
text = path.read_text(encoding="utf-8")

delete_block = '''\tEOS.Connect.ConnectInterface.delete_device_id(EOS.Connect.DeleteDeviceIdOptions.new())
\tvar delete_ret = await IEOS.connect_interface_delete_device_id_callback
\tif not EOS.is_success(delete_ret):
\t\t_log.debug("Failed to delete device id: result_code=%s" % EOS.result_str(delete_ret))
\t
'''
if delete_block in text:
    text = text.replace(delete_block, "", 1)

old = '''\tif not EOS.is_success(create_ret):
\t\t_log.error("Failed to create device id: result_code=%s" % EOS.result_str(create_ret))
\t\treturn false
'''
new = '''\t# DuplicateNotAllowed means this installation already owns a Device ID.
\t# Reusing it is required for lobby rejoin and host-migration identity.
\tif not EOS.is_success(create_ret) and create_ret.result_code != EOS.Result.DuplicateNotAllowed:
\t\t_log.error("Failed to create device id: result_code=%s" % EOS.result_str(create_ret))
\t\treturn false
'''
if old in text:
    text = text.replace(old, new, 1)
elif "DuplicateNotAllowed means this installation" not in text:
    raise SystemExit("EOSG hauth.gd did not match the audited 2.3.1 source")

path.write_text(text, encoding="utf-8", newline="\n")
