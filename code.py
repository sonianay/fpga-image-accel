# @file code.py
# Microcode to be uploaded via Mu Editor to Adafruit QT Py RP2040.
# Sends random 8-bit UART messages to test FPGA.
#
# @author Anay Soni

import time
import board
import random

import digitalio
import neopixel_write
import busio

# NeoPixel power
power_pin = digitalio.DigitalInOut(board.NEOPIXEL_POWER)
power_pin.direction = digitalio.Direction.OUTPUT
power_pin.value = True

# NeoPixel data
pixel_pin = digitalio.DigitalInOut(board.NEOPIXEL)
pixel_pin.direction = digitalio.Direction.OUTPUT
pixel_green = bytearray([50, 0, 0])
pixel_off = bytearray([0, 0, 0])  

# Blinking interval
blink_interval = 0.025
last_blink_time = time.monotonic()
led_state = False

# UART configuration (only TX, RX pins work for this class.....)
# 8 data bits, no parity bits, 1 stop bit
# Start bit is active low, stop bit is active high
uart = busio.UART(board.TX, board.RX, baudrate=115200)

while True:
    now_time = time.monotonic()

    if now_time - last_blink_time >= blink_interval:
        last_blink_time = now_time
        led_state = not led_state

        if led_state:
            # Generate random 8 bit byte (0 to 255)
            rand_val = random.randint(0, 255)
            tx_bytes = bytes([rand_val])

            print(f"time: {now_time}, Sent: 0x{rand_val:02X}")
            # print("Hey Paulie I'm walkin ova here!!!")
            neopixel_write.neopixel_write(pixel_pin, pixel_green)
            uart.write(tx_bytes)
        else:
            neopixel_write.neopixel_write(pixel_pin, pixel_off)
