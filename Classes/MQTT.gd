class_name MQTT extends Node

const tick_time = 1000

var port = 1883
var host = '192.168.1.73'
var client_id = 'Godot'
var ssl = false
var user = ''
var password = ''
var keepalive = 0
var error = null
var message_handler = func(x): print(x)
var read_timer = 0

var sock:StreamPeerTCP


func _ready():
	pass # Replace with function body.


func _process(delta):
	self.read_timer += delta
	
	if self.read_timer > tick_time:
		var op = self.wait_msg()
		if op == 0x90:
			resp = self.sock.read(4)
			
			assert(resp[1] == pkt[2] and resp[2] == pkt[3])
			if resp[3] == 0x80:
				self.error = resp[3]


func _send_str(s:String):
	var payload = [
		len(s) & 0xFF,
		(len(s) >> 8) & 0xFF
	]
	payload.append_array(s.to_utf8_buffer())
	
	self.sock.write(payload)


func connect_to_host(clean_session=true):
	self.sock = StreamPeerTCP.new()
	
	self.sock.connect_to_host(self.host, self.port)
	
#	if self.ssl:
#		import ussl
#		self.sock = ussl.wrap_socket(self.sock, **self.ssl_params)
	
	var premsg = [10,0,0,0,0,0]
	var msg = [
		16, # Length
		0, 0, 0, 0, # Reserved
		0, 0, 0, 0, # Reserved
	]
	
	var sz = 10 + 2 + len(self.client_id)
	msg[6] = clean_session << 1
	if self.user:
		sz += 2 + len(self.user) + 2 + len(self.pswd)
		msg[6] |= 0xC0
	
	if self.keepalive:
		assert(self.keepalive < 65536)
		msg[7] |= self.keepalive >> 8
		msg[8] |= self.keepalive & 0x00FF
	if self.lw_topic:
		sz += 2 + len(self.lw_topic) + 2 + len(self.lw_msg)
		msg[6] |= 0x4 | (self.lw_qos & 0x1) << 3 | (self.lw_qos & 0x2) << 3
		msg[6] |= self.lw_retain << 5
	
	var i = 1
	
	while sz > 0x7f:
		premsg[i] = (sz & 0x7f) | 0x80
		sz >>= 7
		i += 1
	
	premsg[i] = sz


func disconnect_from_host():
	self.sock.write([0xE0,0x00,0x00])
	self.sock.disconnect_from_host()


func ping():
	self.sock.write([0xC0,0x00])


func subscribe(topic, qos=0):
	assert(!self.message_handler, "MQTT subscribe callback not set")
	
	var pkt = [0x82,0x00,0x00,0x00]
	var struct = {}
	
	self.pid += 1
	struct.pack_into("!BH", pkt, 1, 2 + 2 + len(topic) + 1, self.pid)
	#print(hex(len(pkt)), hexlify(pkt, ":"))
	self.sock.put_data(pkt)
	self._send_str(topic)
	self.sock.put_data(qos.to_bytes(1, "little"))
