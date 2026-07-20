# ALF_gradient_and_classification_VHDL# ALF Gradient and Classification in VHDL

This repository contains the VHDL hardware implementation for computing the local gradients and determining the block classification index for the Adaptive Loop Filter (ALF). 

This repository includes the main VHDL module (`ALF_teste.vhd`), the verification environment (`alf_testebench.vhd`), and the compressed test vectors.

## Data Source

The test vectors and spreadsheet data provided for the simulation were extracted directly from the VTM (VVC Test Model) reference software. 
* **Resolution:** 1080p video 
* **Duration:** 1 frame
* **Quantization Parameter (QP):** 32

## Simulation Guide

To compile and simulate this project using ModelSim (or QuestaSim), follow these steps:

### 1. Extract the Test Vectors
Download the compressed archive containing the test vectors (`vetores_alf.rar` or `.zip`). You must extract the contents of this archive directly into the **same folder** where your VHDL design (`ALF_teste.vhd`) and testbench (`alf_testebench.vhd`) are located. The testbench relies on reading these extracted files locally.

### 2. Compile in ModelSim
1. Open ModelSim and set your working directory to the folder containing the extracted files.
2. Create a new work library (if you haven't already).
3. Compile the design files in the following order:
   * First, compile the main module: `ALF_teste.vhd`
   * Next, compile the testbench: `alf_testebench.vhd`

### 3. Run the Simulation
1. Start the simulation by loading the testbench module (`alf_testebench`).
2. In the ModelSim transcript/command line interface, execute the following command to process all test vectors:
   
   ```tcl
   run -all
