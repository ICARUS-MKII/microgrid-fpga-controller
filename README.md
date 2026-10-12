# FPGA-Based Microgrid Fault Detection and Load Management

UMass Boston senior design project (ICARUS Lab). An FPGA-based controller on an NI myRIO-1900 that detects faults in a microgrid, isolates the faulted part, and keeps critical loads powered. It is tested in two stages: a real-time simulation on OPAL-RT, and a low-voltage DC testbed.

## Overview

A fault on a line can trip loads and cascade into a larger blackout. Our controller reads voltage and current, decides what to do, and opens or closes switches so the faulted section is isolated while critical loads stay on.

- **Stage 1 (simulation, CHIL):** OPAL-RT simulates a bus grid with our microgrid connected to it. Faults are injected in the simulation. Voltage and current signals go to the myRIO, which sends switching commands back to OPAL-RT. The ML model runs on a PC alongside the Simulink model.
- **Stage 2 (physical testbed):** A DC supply feeds a load and a critical load (LEDs) through a grid switch and relays, with a rechargeable battery as backup. Sensors feed the myRIO, which commands a custom relay-driver PCB. A fault injector creates short circuits.

Both stages use the same controller logic. Only the measurement front end changes (AC magnitude and frequency in Stage 1, direct DC readings in Stage 2). Values are converted before the same thresholds, state machine, and load priority are applied.

## Controller behavior

State machine: **Normal -> Fault detected -> Isolated -> Restored**

- **Blackout:** bus voltage is lost. The controller opens the grid switch, connects the battery, keeps the critical load on, and sheds the other load.
- **Short circuit:** shows up as overcurrent on one branch. That branch's switch opens and the rest of the microgrid keeps running.

## System architecture

| Block | Role |
|---|---|
| OPAL-RT | Real-time simulation of the grid, microgrid, and injected faults |
| PC (Simulink + MATLAB) | Grid/microgrid model and ML fault classification (LSTM candidate), trained offline |
| NI myRIO-1900 | Controller. FPGA runs the fast detection and state machine. The ARM processor handles configuration, logging, and monitoring |
| PCB relay driver | Takes 3.3 V logic commands from the myRIO and switches the testbed relays |
| DC testbed | DC supply, grid switch, relays, sensors, battery, LED loads, fault injector |

## Repository structure

```
matlab-simulink/   Simulink/Simscape model and MATLAB ML scripts
labview-fpga/      LabVIEW project (myRIO FPGA and Real-Time VIs)
pcb/               KiCad project for the relay-driver board
interface/         Shared signal definitions between simulation and myRIO
docs/              Proposal, notes, test results
```

The `interface/` folder is the contract between the simulation side and the controller side. It should list every signal: name, units, per-unit scaling, voltage range (the myRIO analog inputs accept 0-5 V or +/-10 V), and threshold values. Update it whenever a signal changes.

## Tools

- LabVIEW 2021 SP1 (32-bit) with the Real-Time Module, FPGA Module, and myRIO Toolkit
- MATLAB / Simulink / Simscape Electrical (models must be exportable to MATLAB R2021 for OPAL-RT)
- OPAL-RT real-time simulator
- KiCad (PCB design)
- Git and Git LFS

## Getting started

```bash
git lfs install
git clone https://github.com/ICARUS-MKII/microgrid-fpga-controller.git
```

Git LFS is required because Simulink (`.slx`), MATLAB data (`.mat`), and LabVIEW (`.vi`, `.ctl`) files are binary.

## Team

Team : Ahmed Ahmed, Arseniy Chalyshev, Finn Register, Jacqueline Nee, Isaac Geren

## Status

In progress

## Standards

IEEE 2030.7-2017 (microgrid controller specification), IEEE 2030.8-2018 (microgrid controller testing), IEEE 2030.11-2021 (DER management systems).
