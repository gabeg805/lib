# ******************************************************************************
# 
# Name:    servo.py
# Author:  Gabriel Gonzalez
# Email:   gabeg@bu.edu
# License: The MIT License (MIT)
# 
# Syntax: import motor.servo
# 
# Description: Configure and control a servo motor.
# 
# Notes: None.
# 
# ******************************************************************************

# Imports
import atexit
import signal
import sys
import time
import RPi.GPIO as GPIO

# ******************************************************************************
class ServoMotor(object):
    '''
    Configure and control a servo motor.
    '''

    # Specs
    Pin       = -1
    Freq      = 50 # [Hz]
    DutyCycle = 2  # [pulses]
    Duration  = 0

    # Exit statuses
    EPIN  = 10
    EFREQ = 11
    EDCYC = 12
    EDUR  = 13
    ESPEC = 14

    # **************************************************************************
    def __init__(self, pin=None, freq=None, cycle=None, dur=None):
        '''
        Constructor.
        '''

        GPIO.setmode(GPIO.BCM)

        if (pin is not None):
            if (self.set_pin(pin) != 0):
                exit(self.EPIN)
            self.setup_pin(self.get_pin(), GPIO.OUT)
        if (freq is not None):
            if (self.set_frequency(freq) != 0):
                exit(self.EFREQ)
        if (cycle is not None):
            if (self.set_duty_cycle(cycle) != 0):
                exit(self.EDCYC)
        if (dur is not None):
            if (self.set_duration(dur) != 0):
                exit(self.EDUR)

        signal.signal(signal.SIGTERM, self.signal_handler)
        signal.signal(signal.SIGINT, self.signal_handler)
        signal.signal(signal.SIGHUP, self.signal_handler)
        signal.signal(signal.SIGQUIT, self.signal_handler)
        atexit.register(GPIO.cleanup)


        return

    # **************************************************************************
    def turn_cw(self, dur=None, pin=None, freq=None, cycle=None):
        '''
        Turn servo in the clockwise direction.
        '''

        if (dur is None):
            dur = self.get_duration()
        if (pin is None):
            pin = self.get_pin()
        if (freq is None):
            freq = self.get_frequency()
        if (cycle is None):
            cycle = self.get_duty_cycle()

        if (not self.is_specs(pin, freq, cycle, dur)):
            return self.ESPEC

        pulse = self.setup_pwm(pin, freq)
        if (pulse is None):
            return -1
        pulse.start(cycle)
        time.sleep(dur)
        pulse.stop()

        return 0

    # **************************************************************************
    def turn_ccw(self, dur=None, pin=None, freq=None, cycle=None):
        '''
        Turn servo in the counter-clockwise direction.
        '''

        if (dur is None):
            dur = self.get_duration()
        if (pin is None):
            pin = self.get_pin()
        if (freq is None):
            freq = self.get_frequency()
        if (cycle is None):
            cycle = self.get_duty_cycle()

        if (not self.is_specs(pin, freq, cycle, dur)):
            return self.ESPEC

        pulse = self.setup_pwm(pin, freq)
        if (pulse is None):
            return -1
        pulse.start(18)
        time.sleep(dur)
        pulse.stop()

        return 0

    # **************************************************************************
    def setup_pin(self, pin, io):
        '''
        Setup GPIO pin.
        '''

        if (not self.is_pin(pin)):
            return self.EPIN

        return GPIO.setup(pin, io)

    # **************************************************************************
    def setup_pwm(self, pin=None, freq=None):
        '''
        Setup the Pulse Width Modulation (PWM).
        '''

        if (pin is None):
            pin = self.get_pin()
        if (freq is None):
            freq = self.get_frequency()

        if (not self.is_pin(pin)):
            return None
        if (not self.is_frequency(freq)):
            return None

        return GPIO.PWM(pin, freq)

    # **************************************************************************
    def set_specs(self, pin, freq, cycle, dur):
        '''
        Set motor specifications.
        '''

        if (not self.is_specs(pin, freq, cycle, dur)):
            return self.ESPEC

        self.set_pin(pin)
        self.set_frequency(freq)
        self.set_duty_cycle(cycle)
        self.set_duration(dur)

        return 0

    # **************************************************************************
    def set_pin(self, pin):
        '''
        Set pin that motor is connected to.
        '''

        if (not self.is_pin(pin)):
            return self.EPIN

        self.Pin = int(pin)
        return 0

    # **************************************************************************
    def set_frequency(self, freq):
        '''
        Set frequency to run motor at [Hz].
        '''

        if (not self.is_frequency(freq)):
            return self.EFREQ

        self.Freq = float(freq)
        return 0

    # **************************************************************************
    def set_duty_cycle(self, cycle):
        '''
        Set duty cycle for motor [pulses/cycle].
        '''

        if (not self.is_duty_cycle(cycle)):
            return self.EDCYC

        self.DutyCycle = float(cycle)
        return 0

    # **************************************************************************
    def set_duration(self, dur):
        '''
        Set duration to keep motor on for [sec].
        '''

        if (not self.is_duration(dur)):
            return self.EDUR

        self.Duration = float(dur)
        return 0

    # **************************************************************************
    def get_pin(self):
        '''
        Return pin.
        '''
        return self.Pin

    # **************************************************************************
    def get_frequency(self):
        '''
        Return frequency.
        '''
        return self.Freq

    # **************************************************************************
    def get_duty_cycle(self):
        '''
        Return duty cycle.
        '''
        return self.DutyCycle

    # **************************************************************************
    def get_duration(self):
        '''
        Return duration.
        '''
        return self.Duration

    # **************************************************************************
    def signal_handler(self, signum=None, frame=None):
        '''
        Handle signals.
        '''
        GPIO.cleanup()
        sys.exit(signum)

    # **************************************************************************
    def is_specs(self, pin, freq, cycle, dur):
        '''
        Check if valid motor specifications.
        '''

        if (not self.is_pin(pin)):
            return False
        if (not self.is_frequency(freq)):
            return False
        if (not self.is_duty_cycle(cycle)):
            return False
        if (not self.is_duration(dur)):
            return False

        return True

    # **************************************************************************
    def is_pin(self, pin):
        '''
        Check if valid pin.
        '''

        try:
            tmp = int(pin)
            if (tmp <= 0):
                return False
        except (TypeError,ValueError) as e:
            return False

        return True

    # **************************************************************************
    def is_frequency(self, freq):
        '''
        Check if valid frequency.
        '''

        try:
            tmp = float(freq)
            if (tmp < 0):
                return False
        except (TypeError,ValueError) as e:
            return False

        return True

    # **************************************************************************
    def is_duty_cycle(self, cycle):
        '''
        Check if valid duty cycle.
        '''

        try:
            tmp = float(cycle)
            if (tmp < 0):
                return False
        except (TypeError,ValueError) as e:
            return False

        return True

    # **************************************************************************
    def is_duration(self, dur):
        '''
        Check if valid time duration.
        '''

        try:
            tmp = float(dur)
            if (dur < 0):
                return False
        except (TypeError,ValueError) as e:
            return False

        return True
