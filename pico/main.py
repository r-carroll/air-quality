# pms5003 is a newer sensor and takes better measurements

import machine 
import time
from pms5003 import PMS5003
import bluetooth
import aioble
import asyncio
from picozero import RGBLED
import struct
    

# Enable enviro power supply!
print("Enabling Enviro+ power supply")
boost_enable = machine.Pin(11, machine.Pin.OUT)
boost_enable.value(True)
time.sleep(2.0)

# Configure the PMS5003 for Enviro+
pmsa003i = PMS5003(
    uart=machine.I2C(0, sda=machine.Pin(4), scl=machine.Pin(5), freq=100000),
    pin_enable=machine.Pin(10),
    pin_reset=machine.Pin(9),
    mode="active"
)
print("PMS5003 configured")

# Setup bluetooth stuff

# RGB  status lights for indicating advertising, connected, and commands recieved.
rgb = RGBLED(red = 22, green = 21, blue = 20)

# ROVER_NAME needs to be a unique name for your sensor.  It will be the advertised bluetooth device name
UNIT_NAME = "Ryan's AQ Sensor"

# Bluetooth parameters
BLE_NAME = f"{UNIT_NAME}"  # You can dynamically change this if you want unique names
BLE_SVC_UUID = bluetooth.UUID(0x181A)  # Environmental Sensing Service
BLE_CHARACTERISTIC_UUID = bluetooth.UUID(0x2A6E)  # Temperature
BLE_APPEARANCE = 0x0300  # Thermometer
BLE_ADVERTISING_INTERVAL = 2000

async def send_data_task(characteristic):
    """Send air quality data to the connected device"""
    print("Begin send data task")
    while True:
        # sending data, blink green
        rgb.blink(colors=[(0, 255, 0),(0, 0, 0)])
        try:
            # Read air quality data
            aq_data = pmsa003i.read()
            print(f"Data: {aq_data}")

            # Create a structured data packet
            # Assuming aq_data has pm10, pm25, and pm100 values
            data_bytes = struct.pack(
                "HHH",  # Format: 3 unsigned shorts (2 bytes each)
                aq_data['pm10'],
                aq_data['pm25'],
                aq_data['pm100']
            )

            # Send data through BLE characteristic
            await characteristic.write(data_bytes)
            print("Data sent")
            # Wait before next reading
            await asyncio.sleep(1)

        except asyncio.CancelledError:
            print("Send data task cancelled")
            break
        except asyncio.TimeoutError:
            print("Timeout sending data.")
            break
        except Exception as e:
            print(f"Error sending data: {e}")
            # Optional: add delay before retry
            await asyncio.sleep(1)
            

async def advertise_n_wait_for_connect():
    """ Run the peripheral mode """
    # Set up the Bluetooth service and characteristic
    ble_service = aioble.Service(BLE_SVC_UUID)
    characteristic = aioble.Characteristic(
        ble_service,
        BLE_CHARACTERISTIC_UUID,
        read=True,
        notify=True,
        write=True,
        capture=True,
    )
    aioble.register_services(ble_service)

    print(f"{BLE_NAME} starting to advertise")
    global rgb
    while True:
        # advertising on, blink blue
        rgb.blink(colors=[(0, 0, 255),(0, 0, 0)])
        async with await aioble.advertise(
            BLE_ADVERTISING_INTERVAL,
            name=BLE_NAME,
            services=[BLE_SVC_UUID],
            appearance=BLE_APPEARANCE) as connection: # type: ignore
            print(f"{BLE_NAME} connected to another device: {connection.device}")
            
            tasks = [
                asyncio.create_task(send_data_task(characteristic)),
            ]
            await asyncio.gather(*tasks)
            print(f"{UNIT_NAME} disconnected")
            break

async def main():
    global rgb
    # Power on, turn red
    rgb.color = (255, 0, 0)
    
    while True:
        tasks = [
            asyncio.create_task(advertise_n_wait_for_connect()),
        ]
        await asyncio.gather(*tasks)

print("About to execute main")
asyncio.run(main())
