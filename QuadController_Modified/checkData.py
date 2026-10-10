# -----------------------------------------------------------------------
# checkTune.py

# API to 

# Author: ____ @ ARES Lab
# Purdue Univeristy (2025)

# The following assumptions are made:
#    
#    
# -----------------------------------------------------------------------

# Imports
from keysight.ads import de
de.close_workspace()
from machine import 
"""
-----------------------------------------------------------------------
Class Name: checkFile
Description: A class that checks for files containing results from a 
            signal analyzer, extracts the relevant data into defined 
            variables. 

-----------------------------------------------------------------------
"""

class checkFile:
    pass

"""
-----------------------------------------------------------------------
Class Name: checkTune
Description: A class that compares desired results to the actual data 
            extracted from the signal analyzer, and determines if the 
            results are within an acceptable range.
-----------------------------------------------------------------------
"""

"""
-----------------------------------------------------------------------
Class Name: checkUpdate
Description: A class that updates the keysight DAC component with the 
            values from checkfile, then tells the Keysight ADS 
            schematic to run and Tune/Sweep the simulation, and then 
            updates variables with new information.
            TODO: Is the data still sent if checkTune is satisfied?
-----------------------------------------------------------------------
"""

"""
-----------------------------------------------------------------------
Class Name: checkActuator
Description: A class that updates the actuators position from the 
            checkUpdate class, then tells the M3-LS Quad Controller 
            to move to the new position ideally in the form of a 
            distance.
-----------------------------------------------------------------------
"""


