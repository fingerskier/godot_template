class_name MQTTClient

signal message_received

var client_id: String
var server: String
var port: int
var user: String
var password: String
var keepalive: int
var ssl: bool
var ssl_params: Dictionary
var pid: int
var cb
var lw_topic
var lw_msg
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
	
	print('MQTT Client created', self.client_id)


func _send_str(s: PackedByteArray):
	print('MQTT send-str', s)
	sock.put_u16(s.size())
	sock.put_data(s)

func _recv_len() -> int:
	var n = 0
	var sh = 0
	while true:
		var b = sock.get_u8()
		n |= (b & 0x7F) << sh
		if b & 0x80 == 0:
			return n
		sh += 7
	return 0

func set_callback(f):
	self.cb = f

func set_last_will(topic: String, msg: String, retain: bool = false, qos: int = 0):
	assert(0 <= qos)
	assert(qos <= 2)
	assert(topic)
	lw_topic = topic
	lw_msg = msg
	lw_qos = qos
	lw_retain = retain

func connect_to_server(clean_session: bool = true) -> int:
	print('Trying to connect MQTT host')
	sock = StreamPeerTCP.new()
	
	sock.connect_to_host(self.server, port)
	
	var premsg = PackedByteArray([0x10, 0, 0, 0, 0, 0])
	var msg = PackedByteArray([0x04, "M", "Q", "T", "T", 0x04, 0x02, 0, 0])
	
	var sz = 10 + 2 + self.client_id.length()
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
		msg[6] |= int(lw_retain)
	
	premsg[1] = sz >> 8
	premsg[2] = sz & 0xFF

	_send_str("MQTT".to_utf8_buffer())
	premsg.append_array(msg)
	premsg.append_array(self.client_id.to_utf8_buffer())
	if user:
		_send_str(user.to_utf8_buffer())
		_send_str(password.to_utf8_buffer())
	if lw_topic:
		_send_str(lw_topic)
		_send_str(lw_msg)
	
	_send_str(premsg)
	var rc = 0
	var len = _recv_len()
	var resp = sock.get_u8()
	if resp == 0x20:
		rc = -1
	if resp != 0x20 or len != 2:
		sock.put_data(PackedByteArray([0xe0, 0]))
		return rc
	resp = sock.get_u8()
	rc = resp << 8
	resp = sock.get_u8()
	rc |= resp
	
	print('MQTT connected', self.server, rc)
	return rc
