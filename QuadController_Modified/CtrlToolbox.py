# -----------------------------------------------------------------------
# CtrlToolbox.py

# API to control M3-LS-1.8-6 Linear Smart Stage

# Author: Alex Santiago @ ARES Lab
# Purdue Univeristy (2025)

# The following assumptions are made:
#    Controller encoder resolution is in nm units.
#    The controller is connected via I2C or SPI.
# -----------------------------------------------------------------------

# import libraries
# from timeit import default_timer as timer  # Timer
from time import sleep  # Delay
from machine import Pin, SPI, SoftSPI, I2C, SoftI2C  # GPIO and SPI/I2C libraries

# -----------------------------------------------------------------------
# Status Flag Bits
# These correspond to the status value returned by command <10>
# -----------------------------------------------------------------------
F_DIRECTION = 0x000002  # DIRECTION FLAG
F_RUNNING = 0x000004  # MOTOR RUNNING
F_INTERLOCK = 0x000008  # INTERLOCK (e.g. not connected or driver not found)
F_NUMBERED_BURSTS = 0x000010  # SPECIFIC NUMBER OF BURSTS COMMAND
F_TIMED_RUN = 0x000020  # TIMED RUN
F_MULTIPLX_PCB = 0x000040  # Multiplexer PCB Connected
F_COMP_CONTROL = 0x000080  # UNDER COMPUTER CONTROL FLAG
F_AT_FWD_LIMIT = 0x000200  # CURRENTLY AT FORWARD LIMIT
F_AT_REV_LIMIT = 0x000400  # CURRENTLY AT REVERSE LIMIT
F_BURST_MODE = 0x000800  # SET TO 1 FOR BURST MODE OPERATION
F_BCKJOB_INPROG = 0x008000  # SET TO 1 WHEN BACKGROUND JOB IN PROGRESS
F_CL_ENC_ERR = 0x010000  # SET IF ENCODER MISSED COUNT ERROR DETECTED
F_CL_ENC_ZERO = 0x020000  # SET IF ZERO MARK READ ENABLED
F_CL_ON_TARGET = 0x040000  # SET IF POSITION = TARGET
F_CL_MV_TARGET = 0x080000  # SET IF MOVING TOWARD A TARGET
F_CL_MAINT_MODE = 0x100000  # MAINTENANCE MODE FOR MAINTAINING POSITION
F_CL_MODE_ENABLE = 0x200000  # SET IF CLOSED LOOP MODE ENABLED
F_CL_ACCEL = 0x400000  # SET IF ACCELERATING
F_CL_STALLED = 0x800000  # SET IF STALLED


class Axis:
    # ---------------------------------------------------------------------------
    # CLASS Axis
    # ---------------------------------------------------------------------------

    def __init__(self, mode='I2C'):
        # -----------------------------------------------------------------------
        # CtrlAxis Class Initialization
        # -----------------------------------------------------------------------
        self.mode = mode  # Communication mode: 'I2C' or 'SPI'
        self.mosi_gpio = -1   # Master Out Slave In GPIO
        self.miso_gpio = -1   # Master In Slave Out GPIO
        self.sck_gpio = -1     # Serial Clock GPIO
        self.cs_gpio = -1       # Chip Select GPIO
        self.scl_gpio = -1       # Serial Clock GPIO
        self.sda_gpio = -1       # Serial Data GPIO

        self.spi_baudrate = 1000000  # Chip Select
        self.i2c_baudrate = 400000  # I2C Baudrate
        self.spi = None            # SPI instance
        self.i2c = None            # I2C instance
        self.i2c_addr = 0x33    # Default I2C address for M3-LS-1.8-6

        self.Axes = 0               # Number of axes found
        self.ID = 0                 # ID number for axis
        self.CtrlType = ""          # Controller Type
        self.SerialNumber = "N/A"   # Serial Number
        self.FwVersion = ""         # Firmware Version
        self.EncRes = 0.0        # Encoder Resolution
        self.EncResUnits = "nm"     # Encoder Resolution Units
        self.EncResUm = 0.0         # Encoder Resolution in um
        self.EncResMm = 0.0       # Encoder Resolution in mm
        self.Status = 0             # Status
        self.PositionEnc = 0        # Position in encoder counts
        self.PositionUm = 0         # Position in um
        self.PositionMm = 0         # Position in mm
        self.ErrorEnc = 0           # Error in encoder counts
        self.ErrorUm = 0            # Error in um
        self.ErrorMm = 0            # Error in mm
        self.FwdLimitEnc = 0        # Forward Limit in encoder counts
        self.FwdLimitUm = 0         # Forward Limit in um
        self.FwdLimitMm = 0         # Forward Limit in mm
        self.RevLimitEnc = 0        # Reverse Limit in encoder counts
        self.RevLimitUm = 0         # Reverse Limit in um
        self.RevLimitMm = 0         # Reverse Limit in mm
        self.LimitWndEnc = 0        # Active Window in encoder counts

    def setSPI(self, mosi_gpio, miso_gpio, sck_gpio, cs_gpio, software=True):
        # GPIO Definitions for SPI
        self.mosi_gpio = mosi_gpio   # Master Out Slave In
        self.miso_gpio = miso_gpio   # Master In Slave Out
        self.sck_gpio = sck_gpio     # Clock
        self.cs_gpio = cs_gpio       # Chip Select

        # Pin Definitions for SPI
        self.mosi_pin = Pin(self.mosi_gpio, Pin.OUT,
                            Pin.PULL_UP)     # Master Out Slave In
        # Master In Slave Out
        self.miso_pin = Pin(self.miso_gpio, Pin.IN, Pin.PULL_UP)
        self.sck_pin = Pin(self.sck_gpio, Pin.OUT, Pin.PULL_UP)       # Clock
        self.cs_pin = Pin(self.cs_gpio, Pin.OUT,
                          Pin.PULL_UP)         # Chip Select

        self.soft = software         # Use software SPI if True, hardware SPI if False

    def initSPI(self):
        # Initialize SPI

        if self.soft:
            self.spi = SoftSPI(baudrate=self.spi_baudrate, polarity=0, phase=0, bits=8, firstbit=SPI.MSB,
                               sck=self.sck_pin, mosi=self.mosi_pin, miso=self.miso_pin)
        else:
            # Determine SPI periphery
            spiN = self.get_spi_instance()

            # SPI Instance Initialization
            self.spi = SPI(spiN, baudrate=self.spi_baudrate, polarity=0, phase=0, bits=8, firstbit=SPI.MSB,
                           sck=self.sck_pin, mosi=self.mosi_pin, miso=self.miso_pin)

    def deinitSPI(self):
        # Deinitialize SPI instance
        if self.spi is not None:
            self.spi.deinit()

    def setI2C(self, sda_gpio, scl_gpio, i2c_baudrate=400000, i2c_addr=0x33, software=True):
        # Configure the I2C GPIO pins
        # Note: I2C requires two GPIO pins, SCL and SDA
        # GPIO Definitions for I2C
        self.scl_gpio = scl_gpio       # Serial Clock
        self.sda_gpio = sda_gpio       # Serial Data
        self.i2c_baudrate = i2c_baudrate  # Baudrate
        self.i2c_addr = i2c_addr       # I2C Address
        self.soft = software  # Use software I2C if True, hardware I2C if False

    def initI2C(self):
        # Initialize I2C

        if self.scl_gpio < 0 or self.sda_gpio < 0:
            raise ValueError("I2C GPIO pins not set. Call setI2C() first.")

        # Pin Definitions for I2C
        # Note: I2C pins are pulled up internally, so no need to set pull-up resistors
        self.scl_pin = Pin(self.scl_gpio, pull=Pin.PULL_UP)  # Serial Clock
        self.sda_pin = Pin(self.sda_gpio, pull=Pin.PULL_UP)  # Serial Data

        # I2C Instance Initialization
        if self.i2c is None:
            if self.soft:
                # Use Software I2C
                self.i2c = SoftI2C(scl=self.scl_pin, sda=self.sda_pin,
                                   freq=self.i2c_baudrate)
            else:
                # Determine I2C periphery
                i2cN = self.get_i2c_instance()
                self.i2c = I2C(i2cN, scl=self.scl_pin, sda=self.sda_pin,
                               freq=self.i2c_baudrate)

    def deinitI2C(self):
        # Deinitialize I2C instance
        if self.soft == False:
            self.i2c = None

    def SendCmd(self, cmd, attempts=25):
        # -----------------------------------------------------------------------
        # SendCmd( cmd )

        # Sends the specified command string through the port and waits
        # for a reply

        # Returns the string received from the port or "N/A"
        # -----------------------------------------------------------------------

        cmd = "<" + cmd + ">\r"  # Format the command with angle brackets and CR
        response = ""

        if self.mode == 'I2C':
            # Ensure I2C is initialized
            self.initI2C()

            # Send command over I2C
            if self.i2c is not None:
                # Write command to I2C
                for attempt in range(attempts):  # Retry up to 10 times
                    try:
                        self.i2c.writeto(self.i2c_addr, cmd)
                        sleep(0.1)  # Wait for the command to be processed (60us)
                        break
                    except Exception as e:
                        pass  # Ignore I2C write errors, will retry

                # Read response from I2C
                # Note: The response length is not fixed, so we read a buffer of 32 bytes
                for attempt in range(attempts):  # Retry up to 10 times
                    try:
                        read_buf = self.i2c.readfrom(self.i2c_addr, 32)
                        sleep(0.1)  # Wait for the command to be processed (60us)

                        # Split by CR to get the command response
                        response = read_buf.decode('ascii').split('\r')[0]
                        break
                    except Exception as e:
                        pass  # Ignore I2C write errors, will retry

                self.deinitI2C()  # Deinitialize I2C after use
            else:
                raise ValueError("I2C not initialized. Call initI2C() first.")

        elif self.mode == 'SPI':
            adk_buf = bytearray(len(cmd))  # Same size as write

            # Start SPI communication
            self.initSPI()

            # Issue the command
            self.cs_pin.value(0)  # Pull down CS to select the device

            if self.spi is not None:
                # Send the command over SPI
                self.spi.write_readinto(cmd, adk_buf)

            # if set(adk_buf) == {1} and len(adk_buf) == len(cmd): # Check that each byte was adknowledged properly

            sleep(0.06)  # Wait for the command to be processed (60us)

            # Allocate buffer for response with max length 64 bytes
            read_buf = bytearray(64)

            if self.spi is not None:
                # Read data into buffer, writing 0x01 to stimulate each bit
                self.spi.readinto(read_buf, 1)

            # read_buf = bytearray()
            # while read_buf[-1] != b'\r':
            #     byte = self.spi.read(1,1) # Read 1 byte while writing 0x01
            #     read_buf.append(int(byte))
            #     sleep(0.06)  # Wait 60us for the next reply byte to be loaded from ram

            self.cs_pin.value(1)  # Pull up CS

            # Stop the SPI communication
            if self.spi is not None:
                self.spi.deinit()
            print(read_buf)
            response = read_buf.decode('ascii')

        # Remove angle brackets and return the response
        response = response.replace('>', "")
        response = response.replace('<', "")
        return response

    def get_spi_instance(self):
        # Lookup table mapping GPIO to valid SPI peripherals
        # Format: { gpio: [allowed SPI instances] }
        SPI_PINMAP = {
            0: [0], 1: [0], 2: [0], 3: [0],
            4: [0], 5: [0], 6: [0], 7: [0],
            8: [1], 9: [1], 10: [1], 11: [1],
            12: [1], 13: [1], 14: [1], 15: [1],
            16: [0], 17: [0], 18: [0], 19: [0]
        }

        candidates = list(set(SPI_PINMAP.get(self.sck_gpio, [])) &
                          set(SPI_PINMAP.get(self.mosi_gpio, [])) &
                          set(SPI_PINMAP.get(self.miso_gpio, [])))
        if not candidates:
            raise ValueError("No compatible SPI instance for given pins")
        return candidates[0]

    def get_i2c_instance(self):
        # Lookup table mapping GPIO to valid I2C peripherals
        # Format: { gpio: [allowed I2C instances] }
        I2C_PINMAP = {
            0: [0], 1: [0],
            2: [1], 3: [1],
            4: [0], 5: [0],
            6: [1], 7: [1],
            8: [0], 9: [0],
            10: [1], 11: [1],
            12: [0], 13: [0],
            14: [1], 15: [1],
            16: [0], 17: [0],
            18: [1], 19: [1],
            20: [0], 21: [0],
            26: [1], 27: [1],
        }

        candidates = list(set(I2C_PINMAP.get(self.scl_gpio, [])) &
                          set(I2C_PINMAP.get(self.sda_gpio, [])))
        if not candidates:
            raise ValueError("No compatible I2C instance for given pins")
        return candidates[0]

    def InitializeAxis(self):
        # -----------------------------------------------------------------------
        # InitializeAxis()

        # Initializes the connection to the controller connected to the port

        # Returns 1 if axis found
        # -----------------------------------------------------------------------

        # Assume no response
        self.Axes = 0

        # Get the Ctrl Type and F/W Version
        # <01> returns <01 1 VER x.y.z CtrlType>
        reply = self.SendCmd("01")
        if len(reply) > 2:
            if reply[:2] == '01':
                self.Axes = 1  # Found actuator
                params = reply.split(' ')
                if len(params) >= 4:
                    self.FwVersion = params[3]  # Get F/W version
                    self.CtrlType = params[4].strip()  # Get controller type
            else:
                return self.Axes

        # Get the serial number
        # <14 020 F> returns 15 characters <14 xxxxxxxxxxxxxxx>
        reply = self.SendCmd("14 020 F")
        if len(reply) > 2:
            if reply[:2] == '14':
                self.SerialNumber = reply[4:].strip()

        # Get the encoder resolution
        # <44> returns <44 v,r,u> where v=vendor, r=resolution, u=units
        reply = self.SendCmd("44")
        if len(reply) > 2:
            if reply[:2] == '44':
                params = reply[3:].split(',')
                if len(params) >= 2:
                    # check to see if the encoder resolution is a fraction (e.g. "9/0.4096")
                    slash = params[1].find('/')
                    if slash >= 0:
                        values = params[1].split('/')
                        numer = float(values[0])
                        denom = float(values[1])
                        self.EncRes = numer / denom
                    else:
                        self.EncRes = float(params[1])

                    # Get encoder resolution units
                    self.EncResUnits = params[2].strip()
                    self.EncResUm = self.EncRes / 1000    # Convert to um
                    self.EncResMm = self.EncResUm / 1000  # Convert to mm

        # Get the soft travel limits (in encoder counts)
        # <46> returns <46 FFFFFFFF RRRRRRRR WWWW> where F..F=Forward Limit, R..R=Reverse Limit, WWWW=ActiveWindow
        reply = self.SendCmd("46")
        if len(reply) > 2:
            if reply[:2] == '46':
                params = reply[3:].split(" ")
                if len(params) >= 2:
                    self.FwdLimitEnc = int(params[0], 16)
                    self.RevLimitEnc = int(params[1], 16)
                    self.LimitWndEnc = int(params[2], 16)

                    self.FwdLimitUm = self.FwdLimitEnc * self.EncResUm
                    self.FwdLimitMm = self.FwdLimitEnc * self.EncResMm
                    self.RevLimitUm = self.RevLimitEnc * self.EncResUm
                    self.RevLimitMm = self.RevLimitEnc * self.EncResMm

        # return the axis count
        return self.Axes

    def Info(self):
        # Show Controller Details
        print("------------------------------------------")
        print("Connected To:         " + self.CtrlType)
        print("\tS/N:                " + self.SerialNumber)
        print("\tF/W Version:        " + self.FwVersion)
        print("\tEncoder Resolution: " + str(self.EncRes) + self.EncResUnits)
        print("\tMax Travel:         " +
              str(self.FwdLimitUm - self.RevLimitUm) + " um")
        if self.mode == 'SPI':
            # Show SPI details
            print("\nSPI:")
            print("\tMOSI GPIO:    " + str(self.mosi_gpio))
            print("\tMISO GPIO:    " + str(self.miso_gpio))
            print("\tSCK GPIO:     " + str(self.sck_gpio))
            print("\tCS GPIO:      " + str(self.cs_gpio))
            print("\tSPI Baudrate: " + str(self.spi_baudrate) + " Hz")
        elif self.mode == 'I2C':
            # Show I2C details
            print("\nI2C:")
            print("\tSDA GPIO:     " + str(self.sda_gpio))
            print("\tSCL GPIO:     " + str(self.scl_gpio))
            print("\tI2C Baudrate: " + str(self.i2c_baudrate) + " Hz")
        print("------------------------------------------")

    def SetCL_Enable(self, ena):
        # -----------------------------------------------------------------------
        # SetCL_Enable(enable)
        #
        # Enables or disables according to the boolean value passed by the caller.
        #
        # Returns True if successful
        # -----------------------------------------------------------------------

        if bool(ena):
            cmd = self.SendCmd("20 1")
            if cmd[:4] == '20 1':
                return True
        else:
            cmd = self.SendCmd("20 0")
            if cmd[:4] == '20 0':
                return True
        return False

    def GetCL_Enable(self):
        # -----------------------------------------------------------------------
        # GetCL_Enable()
        #
        # Returns the current enable/disable state as a boolean
        # -----------------------------------------------------------------------

        cmd = self.SendCmd("20 R")
        if cmd[:4] == '20 1':
            return True
        return False

    def MoveAbsoluteEnc(self, target):
        # -----------------------------------------------------------------------
        # MoveAbsoluteEnc( target_in_enc )
        #
        # Expects signed target in encoder count units
        #
        # Returns True if successful
        # -----------------------------------------------------------------------

        cmd = self.SendCmd("08 " + IntToHex32(target))
        return (cmd[:2] == '08')

    def MoveAbsoluteUm(self, target):
        # -----------------------------------------------------------------------
        # MoveAbsoluteUm( target_in_um )
        #
        # Expects signed target in um units
        #
        # Returns True if successful
        # -----------------------------------------------------------------------

        enc = float(target) / self.EncResUm
        return self.MoveAbsoluteEnc(enc)

    def MoveAbsoluteMm(self, target):
        # -----------------------------------------------------------------------

        # MoveAbsoluteMm( target_in_mm )
        #
        # Expects signed target in mm units
        #
        # Returns True if successful
        # -----------------------------------------------------------------------

        enc = float(target) / self.EncResMm
        return self.MoveAbsoluteEnc(enc)

    def MoveRelativeEnc(self, movedir, distance):
        # -----------------------------------------------------------------------
        # MoveRelativeEnc( direction, distance_in_enc )
        #
        # Expects move direction (0=Rev, 1=Fwd) and distance in encoder units.
        #
        # Returns True if successful
        # -----------------------------------------------------------------------

        if int(movedir) == 0:
            cmd = "06 0"
        else:
            cmd = "06 1"
        cmd = self.SendCmd(cmd + IntToHex32(distance))
        return (cmd[:2] == '06') or cmd

    def MoveRelativeUm(self, movedir, distance):
        # -----------------------------------------------------------------------
        # MoveRelativeUm( direction, distance_in_um )
        #
        # Expects move direction (0=Rev, 1=Fwd) and distance in um units.
        #
        # Returns True if successful
        # -----------------------------------------------------------------------

        enc = float(distance) / self.EncResUm
        return self.MoveRelativeEnc(movedir, enc)

    def MoveRelativeMm(self, movedir, distance):
        # -----------------------------------------------------------------------
        # MoveRelativeMm( direction, distance_in_mm )
        #
        # Expects move direction (0=Rev, 1=Fwd) and distance in mm units.
        #
        # Returns True if successful
        # -----------------------------------------------------------------------

        enc = float(distance) / self.EncResMm
        return self.MoveRelativeEnc(movedir, enc)

    def FreeRun(self, movedir, duration):
        # -----------------------------------------------------------------------
        # FreeRun( direction, opt_duration_in_sec )
        #
        # Expects move direction (0=Rev, 1=Fwd) with optional duration in
        # seconds (pass 0 if none)
        #
        # Returns True if successful
        # -----------------------------------------------------------------------

        if duration > 0:
            if int(movedir) == 0:
                cmd = "04 0 " + IntToHex16(duration*10)
            else:
                cmd = "04 1 " + IntToHex16(duration*10)
        else:
            if int(movedir) == 0:
                cmd = "04 0"
            else:
                cmd = "04 1"
        cmd = self.SendCmd(cmd)
        return (cmd[:2] == '04')

    def Stop(self):
        # -----------------------------------------------------------------------
        # Stop()
        #
        # Sends a stop command.
        #
        # Returns True if successful
        # -----------------------------------------------------------------------

        cmd = self.SendCmd("03")
        return (cmd[:2] == '03')

    def QueryPosStatus(self):
        # -----------------------------------------------------------------------
        # QueryPosStatus()
        #
        # Queries the current motor status and position/error and
        # caches the result in Status, PositionXX and ErrorXX (XX => enc, Um, Mm)
        #
        # Returns True if successful
        # -----------------------------------------------------------------------

        # Command <10> returns "<10 SSSSSS PPPPPPPP EEEEEEEE>"
        cmd = self.SendCmd("10")
        if len(cmd) > 2:
            if cmd[:2] == '10':
                params = cmd[3:].split(' ')
                if len(params) >= 3:
                    self.Status = int(params[0], 16)

                    self.PositionEnc = int(params[1], 16)
                    if self.PositionEnc > 0x7FFFFFFF:
                        self.PositionEnc = -(0xFFFFFFFF - self.PositionEnc + 1)
                    self.PositionUm = self.PositionEnc * self.EncResUm
                    self.PositionMm = self.PositionEnc * self.EncResMm

                    self.ErrorEnc = int(params[2], 16)
                    if self.ErrorEnc > 0x7FFFFFFF:
                        self.ErrorEnc = -(0xFFFFFFFF - self.ErrorEnc + 1)
                    self.ErrorUm = self.ErrorEnc * self.EncResUm
                    self.ErrorMm = self.ErrorEnc * self.EncResMm
                    return True
        return False

    def WaitIdle(self, timeout=5, step=0.05):
        # -----------------------------------------------------------------------
        # WaitIdle( time_out_in_sec )
        #
        # Waits for the motor to stop running up to the caller time out value
        # specified by the caller
        #
        # Returns True if successful (i.e. stops before timer expires)
        # -----------------------------------------------------------------------

        start = 0
        while start < timeout:
            self.QueryPosStatus()
            sleep(step)
            start = start + step

            if (self.Status & F_RUNNING) == 0:
                return True
            elif self.IsStalled():
                return False

        return False

    def IsStalled(self):
        # -----------------------------------------------------------------------
        # IsStalled()
        #
        # Returns True if the motor has been marked as stalled
        # -----------------------------------------------------------------------
        self.QueryPosStatus()
        if (self.Status & F_CL_STALLED) == F_CL_STALLED:
            return True
        elif self.ErrorEnc > 2*self.EncRes:
            return True
        else:
            return False

    def Zero(self):
        # -----------------------------------------------------------------------
        # Zero()
        #
        # Sends a command to zero the encoder count registry
        #
        # Returns True if successful
        # -----------------------------------------------------------------------

        cmd = self.SendCmd("07")
        return (cmd[:2] == '07')

    def PositionStr(self, Units='um'):
        # ------------------------------------------------------------------------------
        # Subroutine to return the current position with the current units
        # ------------------------------------------------------------------------------

        if Units == 'mm':
            return str(self.PositionMm) + Units
        elif Units == 'um':
            return str(self.PositionUm) + Units
        else:
            return str(self.PositionEnc) + Units

    def Home(self):
        # -----------------------------------------------------------------------
        # Home()
        #
        # Sends a command to move to the home position
        #
        # Returns True if successful
        # -----------------------------------------------------------------------

        cmd = self.SendCmd("42 A")
        return (cmd == '42 1')

    def CalibrateFreq(self):
        # -----------------------------------------------------------------------
        # CalibrateFreq()
        #
        # This command is used to optimize the Squiggle® motor resonant drive frequency by, on command,
        # sweeping over a range of frequencies, centered at the specified period, and settling on the
        # frequency at which the best motor performance was detected. Alternatively, this command may be
        # used to incrementally step the frequency in the direction of increasing motor performance
        # (changing the step direction when the performance drops).
        # This command needs to be run at every power‐up or more often in environments where the
        # temperature is changing. When issuing an automatic frequency‐calibration sweep command, the
        # carriage may typically move 250 microns during the frequency sweep. If in closed‐loop mode, the
        # smart stage will return to the current target position automatically.
        # It is best to run this command when system is idle and in the reverse direction for the M3‐LS‐1.8‐6
        # Linear Smart Stage.
        # -----------------------------------------------------------------------

        cmd = self.SendCmd("87 4")
        return (cmd[:4] == '87 4')


def IntToHex32(intval):
    # -----------------------------------------------------------------------
    # IntToHex32( int_value )
    # Returns an 8 digit hex string
    # -----------------------------------------------------------------------

    tmp = int(intval)
    if tmp < 0:
        tmp = 0xFFFFFFFF + tmp + 1
    intstr = "%08X" % tmp
    return intstr


def IntToHex16(intval):
    # -----------------------------------------------------------------------
    # IntToHex16( int_value )
    # Returns an 4 digit hex string
    # -----------------------------------------------------------------------

    tmp = int(intval)
    if tmp < 0:
        tmp = 0xFFFF + tmp + 1
    intstr = "%04X" % tmp
    return intstr