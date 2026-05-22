# Bertec MATLAB GRF Visualizer

Real-time MATLAB visualization of the ground reaction force vector from a Bertec force plate using the Bertec Device SDK for .NET.

## Files

- `test_bertec_read_forces.m`  
  Connects to the Bertec force plate and prints Fx, Fy, Fz, Mx, My, Mz.

- `main_bertec_grf_visualizer.m`  
  Visualizes the real-time ground reaction force vector and estimated center of pressure.

## Requirements

- MATLAB on Windows, 64-bit
- Bertec Device SDK for .NET
- Working Bertec force plate connection
- Bertec SDK files installed locally

## Important

This repository does not include the Bertec SDK, DLLs, documentation, or example source files.  
Users must obtain the SDK directly from Bertec and update the `sdkFolder` path in the MATLAB scripts.

## Usage

1. Install the Bertec Device SDK.
2. Confirm the force plate works in Bertec software.
3. Open the MATLAB scripts.
4. Edit:

```matlab
sdkFolder = 'C:\Path\To\Bertec_Device_SDK_March_2026';