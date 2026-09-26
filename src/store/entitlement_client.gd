extends Node
## The client half of the entitlement server. One HTTP call, three routes.
##
## It lives on the Cloudflare Worker this project already runs (see
## server/signaling/worker.js). That Worker was built for the retired
## signalling path and sits on the free plan; adding three routes to it costs
## nothing and adds no second thing to keep alive. The co-op game itself still
## goes peer to peer over EOS and never touches this.
##
## Nothing secret travels here and nothing secret is stored here. The request
## carries a store receipt, which the store already gave this device; the reply
## carries a token signed by a key this app only has the public half of. There
## is no API credential in the app, which is the point -- see
## docs/monetization.md.

const VERIFY := "/entitlement/verify"
const RENEW := "/entitlement/renew"
const ENROL := "/entitlement/dev-enrol"
## Short on purpose. Buying is the one moment a player is watching a spinner,
## and an unlock that takes half a minute to appear feels broken even when it
## works. A timeout here is not a failure of the purchase: the receipt is still
## on the device and "購入を復元する" will pick it up.
const TIMEOUT := 12.0

## The same Worker the rest of the project points at, and the same saved
## override, so a test deployment moves everything at once rather than leaving
## the store talking to production.
func base_url() -> String:
	var saved := NetLink.recall("relay", "")
	return saved if not saved.is_empty() else Balance.DEFAULT_RELAY

## Exchange a store receipt for an entitlement token.
## Returns {"token": "..."} or {"error": "<what to show the player>"}.
func verify(receipt: Dictionary, puid: String) -> Dictionary:
	var body := receipt.duplicate()
	body["puid"] = puid
	return await _post(VERIFY, body)

## Extend a token that is nearing its expiry, without asking the store again.
## Returns {"token": ...}, {"revoked": true}, or {} when the server could not
## be reached -- and {} deliberately changes nothing.
func renew(token: String, puid: String) -> Dictionary:
	if token.is_empty():
		return {}
	var answer := await _post(RENEW, {"token": token, "puid": puid})
	if answer.has("error"):
		return {}
	return answer

## Bind this device to a developer entitlement.
##
## The phrase is checked by the Worker and is not in this repository, in the
## app, or in any build artefact. The field that sends it is an ordinary,
## visible text box: there is no hidden gesture and no debug build, because a
## hidden unlock in a shipped app is a hidden unlock for everybody who finds
## it. Deleting DEV_ENROL_SECRET on the Worker ends this for good, without an
## app update. See docs/monetization.md.
func enrol_developer(phrase: String, puid: String) -> Dictionary:
	return await _post(ENROL, {"phrase": phrase, "puid": puid})

func _post(path: String, body: Dictionary) -> Dictionary:
	var request := HTTPRequest.new()
	request.timeout = TIMEOUT
	add_child(request)
	var url := base_url().rstrip("/") + path
	var err := request.request(url, ["content-type: application/json"],
		HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		request.queue_free()
		return {"error": "通信を開始できませんでした。"}
	var result: Array = await request.request_completed
	request.queue_free()
	var status := int(result[1])
	var text := (result[3] as PackedByteArray).get_string_from_utf8()
	var parsed = JSON.parse_string(text)
	var answer: Dictionary = parsed if typeof(parsed) == TYPE_DICTIONARY else {}
	if status == 200:
		return answer
	if status == 503:
		# The store's own API is down. Say so rather than implying the purchase
		# failed, because it did not: the receipt is still there.
		return {"error": "ストアの確認サーバに一時的につながりません。"
			+ "しばらくしてから「購入を復元する」をお試しください。"}
	if answer.has("message"):
		return {"error": String(answer["message"])}
	return {"error": TranslationServer.translate("購入を確認できませんでした（%d）。") % status}
