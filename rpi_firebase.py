import serial
import firebase_admin
from firebase_admin import credentials, db
import time
import datetime
import sys

SERVICE_ACCOUNT_KEY = "/home/dongtra/gpbl-40988-firebase-adminsdk-fbsvc-f1b950d250.json"
DATABASE_URL = "https://gpbl-40988-default-rtdb.asia-southeast1.firebasedatabase.app/"
SERIAL_PORT = "/dev/ttyACM0"
BAUD_RATE = 115200

# ================= FIREBASE INIT =================
try:
    cred = credentials.Certificate(SERVICE_ACCOUNT_KEY)
    firebase_admin.initialize_app(cred, {'databaseURL': DATABASE_URL})
    print("Firebase khởi tạo thành công!")
except Exception as e:
    print(f"Lỗi khởi tạo Firebase: {e}")
    sys.exit(1)

ref_latest = db.reference('/smartgarden/device1/latest')
ref_control = db.reference('/smartgarden/device1/control')

# ================= SERIAL CONNECT =================
def connect_serial():
    while True:
        try:
            ser = serial.Serial(SERIAL_PORT, BAUD_RATE, timeout=1)
            time.sleep(2)  # ⚠️ đợi Arduino boot (rất quan trọng)
            print(f"Kết nối Serial thành công: {SERIAL_PORT}")
            return ser
        except Exception as e:
            print(f"Lỗi kết nối Serial: {e}. Thử lại sau 5 giây...")
            time.sleep(5)

ser = connect_serial()
print("Bắt đầu lắng nghe dữ liệu từ Arduino...")

last_data = None

# ================= FIREBASE CONTROL LISTENER =================
def on_control_change(event):
    global ser
    try:
        print("Listener /control triggered!")
        print("Path:", event.path)
        print("Data:", event.data)

        if event.data is None:
            return

        # Firebase gửi toàn object
        if isinstance(event.data, dict):
            new_mode = event.data.get('mode', 0)
            new_pump = event.data.get('pump', 0)
            new_motor = event.data.get('motor', 0)

        # Firebase gửi từng field (mode/pump/motor)
        else:
            data = ref_control.get()
            if not data:
                return
            new_mode = data.get('mode', 0)
            new_pump = data.get('pump', 0)
            new_motor = data.get('motor', 0)

        cmd = f"CMD:mode={new_mode},pump={new_pump},motor={new_motor}\n"

        print("Sending to Arduino:", cmd.strip())
        ser.write(cmd.encode())

    except Exception as e:
        print(f"Lỗi listener control: {e}")

control_listener = ref_control.listen(on_control_change)

# ================= MAIN LOOP =================
while True:
    try:
        if ser.in_waiting > 0:
            line = ser.readline().decode('utf-8', errors='ignore').strip()

            if line.startswith("DATA:"):
                data = line[5:].split(',')

                if len(data) >= 7:
                    try:
                        temperature = float(data[0])
                        humidity = float(data[1])
                        waterLevel = int(data[2])
                        pumpState = int(data[3])
                        motorState = int(data[4])
                        mode = int(data[5])
                        alert = int(data[6])

                        current_data = [
                            temperature, humidity, waterLevel,
                            pumpState, motorState, mode, alert
                        ]

                        # Chỉ update Firebase khi dữ liệu đổi
                        if last_data != current_data:
                            timestamp = int(time.time())

                            ref_latest.set({
                                'temperature': temperature,
                                'humidity': humidity,
                                'waterLevel': waterLevel,
                                'pumpState': pumpState,
                                'motorState': motorState,
                                'mode': mode,
                                'alert': alert,
                                'timestamp': timestamp,
                                'lastUpdate': datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
                            })

                            # Nếu AUTO mode → sync control
                            if mode == 0:
                                ref_control.update({
                                    'pump': pumpState,
                                    'motor': motorState
                                })
                                print(f"[AUTO] Đồng bộ control: pump={pumpState}, motor={motorState}")

                            print(f"[{datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] "
                                  f"Updated: Temp={temperature:.1f}, Hum={humidity:.1f}, "
                                  f"Water={waterLevel}, Pump={pumpState}, Motor={motorState}, "
                                  f"Mode={mode}, Alert={alert}")

                            last_data = current_data.copy()

                    except ValueError as ve:
                        print(f"Lỗi parse: {ve} - Dòng: {line}")

        time.sleep(0.1)

    except serial.SerialException as se:
        print(f"Serial disconnect: {se}. Thử lại...")
        ser.close()
        ser = connect_serial()
        time.sleep(2)

    except Exception as e:
        print(f"Lỗi: {e}")
        time.sleep(5)