# AutomatedResonantCavityTuning
Automated tuning framework for evanescent-mode cavity and Substrate Integrated Waveguide (SIW) filters.

---

## 📌 Overview

Microwave cavity filters are critical components in modern communication and RF systems. Cascading multiple resonant cavities are essential to maximize energy efficiency and frequency selectivity while minimizing insertion loss which is critical in communications, medical devices, scientific technology, and defense systems. To function correctly, each cavity's physical dimensions must be precisely tuned to align with the desired center frequency and bandwidth. In practice, manufacturing tolerances, material variations, and external coupling effects often degrade the ideal resonator characteristics resulting in dysfunctional devices. While mechanical tuning elements, such as actuator-controlled tuning disks, can compensate for these deviations, the filter becomes highly non-linear when more than two resonators are coupled. Traditional manual or iterative actuator tuning for higher-order filters is time-consuming and computationally expensive. This repository provides an automated, hardware-in-the-loop tuning pipeline that employs a series of algorithms which adjusts physical discs to achieve target filter responses across a wide frequency range.

---

## ✨ Key Features

* **Algorithmic and Manual Tuning:** Supports several tuning algorithms (two forms of sweeping algorithms and two forms of gradient descent) as well as a manual tuning option.
* **Live VNA View:** Can connect to a selection of VNA's displaying live data.
* **Position Logging:** Can log a user selected position as well as recall any logged data.
* **Hardware-in-the-Loop Integration:** Works seamlessly with MATLAB, RP-2350 Microcontroller, and VNA automation interfaces (SCPI) to form an automated closed-loop tuning setup.
* **Wideband Tuning:** Supports reconfigurable filter alignment across broad tuning ranges.

---

## 🏗 System Architecture

1. **ARES Micro-App:** The system controller, where the user can execute an algorithm or manually tune the DUT, pulling data from the VNA and updating the microcontroller.
2. **VNA:** Initiates measurements, capturing raw data.
3. **Microcontroller:** Receives positional commands from the Micro-App updating actuator movements.

---

## 🚀 Getting Started

### Prerequisites

* **MATLAB** (R2025a or newer recommended)
  * Optimization Toolbox
  * Symbolic Math Toolbox
  * Instrument Control Toolbox

### Installation

Clone the repository to your local machine:

```bash
git clone [https://github.com/AlexDCode/AutomatedResonantCavityTuning.git](https://github.com/AlexDCode/AutomatedResonantCavityTuning.git)
cd AutomatedResonantCavityTuning
