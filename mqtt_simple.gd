extends Node

class MQTTException extends Exception:
	pass

class MQTTClient:
	var client_id: String
	var server: String
	var port: int
	var user: String
	var password: String
	var keepalive: int
	var ssl: bool
	var ssl_params: Dictionary
	var pid: int
	var cb: FuncRef
	var lw_topic: String
	var lw_msg: String
	var lw_qos: int
	var lw_retain: bool
	var sock: StreamPeerTCP

	func _init(client_id: String, server: String, port: int = 0, user: String = "", password: String = "", keepalive: int = 0, ssl: bool = false, ssl_params: Dictionary = {}):
		if port == 0:
			port = 8883 if ssl else 1883
		self.client_id = client_id
		self.sock = null
		self.server = server
		self.port = port
		self.ssl = ssl
		self.ssl_params = ssl_params
		self.pid = 0
		self.cb = null
		self.user = user
		self.password = password
		self.keepalive = keepalive
		self.lw_topic = null
		self.lw_msg = null
		self.lw_qos = 0
		self.lw_retain = false

	func _send_str(s: String):
		sock.put_u16(s.length())
		sock.put_data(s.to_ascii())

	func _recv_len() -> int:
		var n = 0
		var sh = 0
		while true:
			var b = sock.get_u8()
			n |= (b & 0x7F) << sh
			if b & 0x80 == 0:
				return n
			sh += 7

	func set_callback(f: FuncRef):
		cb = f

	func set_last_will(topic: String, msg: String, retain: bool = false, qos: int = 0):
		assert(0 <= qos <= 2)
		assert(topic)
		lw_topic = topic
		lw_msg = msg
		lw_qos = qos
		lw_retain = retain

	func connect(clean_session: bool = true) -> int:
		sock = StreamPeerTCP.new()
		var addr = IPAddress.new()
		addr.set_ipv4(sock.resolve_hostname(server))
		sock.connect_to_host(addr, port)

		var premsg = PoolByteArray([0x10, 0, 0, 0, 0, 0])
		var msg = PoolByteArray([0x04, ord("M"), ord("Q"), ord("T"), ord("T"), 0x04, 0x02, 0, 0])

		var sz = 10 + 2 + client_id.length()
		msg[6] = int(clean_session) << 1
		if user:
			sz += 2 + user.length() + 2 + password.length()
			msg[6] |= 0xC0
		if keepalive:
			assert(keepalive < 65536)
			msg[7] |= keepalive >> 8
			msg[8] |= keepalive & 0x00FF
		if lw_topic:
			sz += 2 + lw_topic.length() + 2 + lw_msg.length()
			msg[6] |= 0x4 | (lw_qos & 0x1) << 3 | (lw_qos & 0x2) << 3
			msg[6] |= int(lw_retain
