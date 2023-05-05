import sys
import serial


def connect(port, baudrate=115200):
    try:
        ser = serial.Serial(port, baudrate)
        return ser
    except Exception as e:
        print("Error:", e)
        return None


def read(ser):
    if ser:
        try:
            line = ser.readline().decode().strip()
            return line
        except Exception as e:
            print("Error:", e)
            return None
    else:
        return None


def write(ser, data):
    if ser:
        try:
            ser.write(data.encode())
        except Exception as e:
            print("Error:", e)


def close(ser):
    if ser:
        ser.close()


if __name__ == "__main__":
    command = sys.argv[1]
    ser = None

    if command == "connect":
        ser = connect(sys.argv[2], int(sys.argv[3]))
    elif command == "read":
        print(read(ser))
    elif command == "write":
        write(ser, sys.argv[2])
    elif command == "close":
        close(ser)
