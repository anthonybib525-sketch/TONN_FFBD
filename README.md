# TONN_FFBD
Final project code for topology optimization using bounded-disk Fourier-feature neural density representation.
## Code Organization

This repository contains one main TONN-FFBD solver and several study scripts used to generate the final project results.

### Main Solver

`src/TONN_FFBD_Main.py`

This is the main implementation of the TONN-FFBD topology optimization solver. It contains the neural density representation, bounded-disk Fourier feature mapping, finite-element analysis, SIMP material interpolation, optimization loop, and plotting utilities.

### Study Scripts

`studies/TONNFFBD_vs_TOP88_Study.py`

Runs the benchmark comparison between the TONN-FFBD solver and the classical TOP88-style topology optimization solver. The study compares optimized topologies and final compliance values for selected benchmark cases.

`studies/Upsampling_Validation.py`

Evaluates whether a neural network trained on a coarse finite-element mesh can be sampled on a finer mesh to produce a structurally meaningful high-resolution topology. The study compares the upsampled design against a directly trained high-resolution design.

`studies/CvsFV_Plot_Production.py`

Generates the compliance-versus-Fourier-feature-vector study. This script evaluates the sensitivity of the optimized topology and final compliance to the number of bounded-disk Fourier feature vectors.

`studies/TONNFF_BD_LengthScale_Verification_Study.py`

Runs the bounded-disk Fourier feature length-scale verification study. This script evaluates how the selected Fourier frequency bound affects local feature-size behavior and produces violation maps or related length-scale diagnostics.

### MATLAB Benchmark

`matlab/TOP88_batch_MBB_Tip_VF_study_Heaviside.m`

Contains the MATLAB TOP88-style benchmark solver with boundary conditions aligned to the TONN-FFBD cases. The solver includes density filtering and smooth Heaviside projection for a more comparable regularized benchmark.
