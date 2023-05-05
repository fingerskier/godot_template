extends Node

var python_path = "python" # Change this to your Python executable path if necessary
var script_path = "serial_comm.py"
var port = "COM4" # Change this to your serial port (e.g., /dev/ttyUSB0 on Linux)
var baudrate = 115200


func _ready():
	var output = []

	# Connect to the serial port
	OS.execute(python_path, [script_path, "connect", port, str(baudrate)], output)
	
	# Send data to the serial port
	OS.execute(python_path, [script_path, "write", "Hello, Serial!"], output)
	
	# Read data from the serial port
	var exit_code = OS.execute(python_path, [script_path, "read"], output)
	
	if exit_code == 0:
		print("Received:", output[0])
	else:
		print("Error reading from serial port")
	
	# Close the serial port
	OS.execute(python_path, [script_path, "close"], output)
