# 17 20 22 18
# -----------------------------------------------------------------------
# CtrlToolbox.py

# API to control M3-LS-1.8-6 Linear Smart Stage

# Author: Alex Santiago @ ARES Lab
# Editor: Peter Skrsla @ ARES LAB
# Purdue Univeristy (2026)


# -----------------------------------------------------------------------

# Cmap: Command Map
"""
C00: EXIT                
C01: Calibrate           C02: Recall Last Log   C03: Specify gaps
C04: Specify one gap     C05: Get Log           C06:

For C03, Enter: C03 gap_val gap_val gap_val gap_val
For C04, Enter: C04 actuator_# gap_val
"""
import CtrlToolbox
from utime import sleep, sleep_ms, sleep_us
import sys
import os

os.chdir('/')

n = [3, 2, 1, 4]  # Axis order to be used (0-3 for four axes)
nAxes = len(n)  # Number of axes

EXECUTE = "EXECUTE:"
GAP = "GAP: "
ENDP = "endP" #end process

BASE_CMD_SIZE = 4

sda_Jn = [16, 26, 20, 18]  # GPIO pin for I2C SDA
scl_Jn = [17, 27, 21, 19]  # GPIO pin for I2C SCL

sda_gpio = []
scl_gpio = []
for each in range(len(n)):
    n[each] = n[each] - 1  # Convert to zero-based index
    sda_gpio.append(sda_Jn[n[each]])
    scl_gpio.append(scl_Jn[n[each]])

baud = 400*1000
Axis = []
idx = []
axes = None
positions = None
soft_rev_limit = None

def log_positions(testname, gap):
    with open("axis_positions.log", "a") as log_file:
        log_file.write('Log: ' + testname + "\n")
        for n in idx:
            log_file.write(
                f"Axis {n+1}\tPosition: {Axis[n].PositionStr('um')}\tGap: {gap[n]} um\tRev Limit: {Axis[n].RevLimitEnc}\n")
        log_file.write("----------------\n")

def load_Calibration():
    calibration = []
    try:
        with open("axis_positions.log", "r") as log_file:
            lines = log_file.readlines()

            last_log_index = None
            for i, line in enumerate(lines):
                if line.startswith("Log:"):
                    last_log_index = i
                if line.startswith("----------------"): #May want to change this if the log format changes to: "end log" or something similar
                    end_log_index = i

            if last_log_index is None:
                raise ValueError("No Log entry found in the file.")

            lines = lines[last_log_index:end_log_index]
            for line in lines:
                if line.startswith("Axis"):
                    parts = line.split("\t")
                    axis_num = float(parts[0].split(' ')[1])
                    pos = float(parts[1].split(":")[1].strip('um').split()[0])
                    gap_enc = float(parts[2].split(":")[1].strip().split()[0])
                    soft_rev_limit = float(parts[3].split(":")[
                                           1].strip().split()[0])
                    calibration.append(
                        [axis_num, pos, gap_enc, soft_rev_limit])
    except FileNotFoundError:
        print("No log file found.")
    except Exception as e:
        print("Error loading calibration:", e)
    return calibration

def calibrate(args = None)->None:
    # Set the soft reverse limit
    for n in range(0, nAxes):
        Axis[n].MoveAbsoluteUm(Axis[n].RevLimitUm)
    sleep(3)
    for n in range(0, nAxes):
        Axis[n].QueryPosStatus()
        sleep_us(60)
        Axis[n].MoveAbsoluteUm(int(Axis[n].PositionUm - 1))
        sleep_us(60)
        Axis[n].QueryPosStatus()
        Axis[n].RevLimitEnc = Axis[n].PositionEnc
        Axis[n].RevLimitUm = Axis[n].PositionUm
        Axis[n].RevLimitMm = Axis[n].PositionMm
        idx.append(n)
    sleep_ms(500)

    # Move all axes to their forward limit
    for n in idx:
        Axis[n].MoveAbsoluteUm(Axis[n].FwdLimitUm)
    sleep_us(100)
    for n in idx:
        Axis[n].WaitIdle()

def recall_vals(args = None)->None:
    calibration = load_Calibration()
    # Assign arrays with cal data
    calibration = list(zip(*calibration))  # Transpose the list of lists
    axes = calibration[0]
    positions = calibration[1]
    gaps = calibration[2]
    soft_rev_limit = calibration[3]
    if len(axes) > 0:
        for n in range(0, len(axes)):
            Axis[n].RevLimitEnc = soft_rev_limit[n]
            Axis[n].RevLimitUm = soft_rev_limit[n] * Axis[n].EncResUm
            Axis[n].RevLimitMm = soft_rev_limit[n] * Axis[n].EncResMm

            Axis[n].MoveAbsoluteUm(positions[n])
            Axis[n].WaitIdle()
            Axis[n].QueryPosStatus()

    else:
        print("No calibration data found.")

    for n in range(0, len(axes)):
        idx.append(n) 

def set_all_gaps(gap_data)->None:
    if len(idx) > 0:
        # if soft_rev_limit == None:
        gap = [4000.0, 4000.0, 4000.0, 4000.0]
        # else:
        #      gap = [gaps[n] for n in range(nAxes)]
        try: 
            str = gap_data.split()
            if str[0].lower() == 'log' or str[0].lower() == 'log:':
                testname = " ".join(str[1:])
                log_positions(testname, gap)
                
            else:
                for n in range(len(str)):
                    if str[n].isdigit():
                        gap[n] = float(str[n])
                    else:
                        print("Invalid input. Please enter numeric values only.")
                        break
                for n in idx:
                    Axis[n].MoveAbsoluteUm(
                        int(Axis[n].RevLimitUm + gap[n] + 1))
                sleep_us(100)
                for n in idx:
                    Axis[n].WaitIdle()    
        except ValueError:
            print("\nInvalid input. Please enter a numeric value for the gap.")
        except Exception as e:
            print('\nError: ', e)
            sys.exit(1)
        except KeyboardInterrupt:
            print("\nExiting...")
            sys.exit(1)

def set_one_gap(str_in)->None:
    if len(idx) > 0:
        try: 
            # Split the string by whitespace into a list of arguments
            args = str_in.split()
            
            # Check for logging commands first
            if args and (args[0].lower() == 'log' or args[0].lower() == 'log:'):
                testname = " ".join(args[1:])
                log_positions(testname, args) # Note: You may want to review what 'gap' format log_positions expects
                
            else:
                # Safety check: Ensure we received exactly 2 arguments (actuator_num and gap)
                if len(args) < 2:
                    print("Error: Missing arguments. Expected format: 'C04 [actuator_num] [gap]'")
                    return

                # Validate and parse the arguments cleanly from the split list
                if args[0].isdigit() and args[1].isdigit():
                    actuator_num = int(args[0])
                    target_axis = actuator_num - 1
                    gap_val = int(args[1])

                    if target_axis in idx:
                        Axis[target_axis].MoveAbsoluteUm(
                            int(Axis[target_axis].RevLimitUm + gap_val + 1))
                        sleep_us(100)  
                        Axis[target_axis].WaitIdle()
                else:
                    print("Invalid input values. Both actuator number and gap must be integers.")
               
        except ValueError:
            print("\nInvalid input. Please enter a numeric value for the gap.")
        except Exception as e:
            print('\nError: ', e)
            sys.exit(1)
        except KeyboardInterrupt:
            print("\nExiting...")
            sys.exit(1)

def exit_(args = None)->bool:
    return True

def getLog(args = None)->None:
    try:
        # Open the file on the Pico's internal flash
        with open("axis_positions.log", "r") as f:
            print("---START_FILE_TRANSFER---")
            for line in f:
                # print() sends it straight down the serial USB line
                print(line.strip()) 
            print("---END_FILE_TRANSFER---")
    except Exception as e:
        print("ERROR: Could not read file:", e)

def setup_Cmap():
    Cmap = {
        "C00": exit_,
        "C01": calibrate,
        "C02": recall_vals,
        "C03": set_all_gaps, 
        "C04": set_one_gap,
        "C05": getLog
    }
    return Cmap

def main():
    # Initialize and home each axis
    for n in range(0, nAxes):
        Axis.append(CtrlToolbox.Axis())

        try:
            Axis[n].setI2C(sda_gpio[n], scl_gpio[n], baud, software=True)
            sleep_ms(50)
            Axis[n].InitializeAxis()
            Axis[n].QueryPosStatus()
            sleep_ms(50)
            Axis[n].Home()
        except UnicodeError:
            Axis[n].setI2C(sda_gpio[n], scl_gpio[n], baud, software=False)
            Axis[n].InitializeAxis()

            print("Retrying with Hardware I2C: ", n+1)

            sleep_ms(50)
            break
        except Exception as e:
            print('\nError: ', e)

    # Move to the center and calibrate frequency
    for n in range(0, nAxes):
        Axis[n].WaitIdle()

    for n in range(0, nAxes):
        Axis[n].MoveAbsoluteUm(
            (Axis[n].FwdLimitUm + Axis[n].RevLimitUm)/2)
    sleep_ms(100)
    for n in range(0, nAxes):
        Axis[n].WaitIdle()
    sleep_ms(100)
    for n in range(0, nAxes):
        #print("Calibrating Frequency Axis: ", n+1)
        Axis[n].CalibrateFreq()

    axes = None
    positions = None
    soft_rev_limit = None
    
    # Take User Inputs
    Cmap = setup_Cmap()
    runCmd = ""
    exit = False
    
    while(not exit):
        print(EXECUTE)
        runCmd = input().strip()
        cmdArgs = runCmd[3:].strip() if len(runCmd[3:]) > 1 else None
        runCmd = runCmd[0:3].upper()
        
        action = Cmap.get(runCmd, lambda *args: print("Invalid Command!"))

        # Run the selected function
        result = action(cmdArgs)
        print(ENDP)
        
        if result == True:
            exit = True

if __name__ == "__main__":
    main()