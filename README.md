# pmacsAmicoNoddi
Wrapper to run the AMICO implementation of NODDI on the PMACS cluster

## Input

DWI data in the format /path/to/dwi.[nii.gz, bvec, bval]
Brain mask (.nii.gz)

## NODDI model

The model is explained in detail in the original [NODDI
paper](https://pubmed.ncbi.nlm.nih.gov/22484410/). Briefly, given

* A_t - normalized DWI signal (the data we're fitting to, normalized by the
        average b=0 signal)

NODDI fits

```
  A_t = V_{iso} * A_iso + (1 - V_{iso}) * [ V_{icv} * A_{icv} + (1 - V_{icv}) * A_{ecv} ]
```
where

* A_{iso} - model of the isotropic signal
* A_{icv} - model of the intracellular signal
* A_{ecv} - model of the extracellular signal
* V_{icv} - intracellular volume fraction (output as FIT_ICVF)
* V_{iso} - isotropic volume fraction (output as FIT_ISOVF)

The other outputs discussed below, FIT_OD and FIT_dir, are additional parameters
used to model A_{icv} and A_{ecv}.

## Output

NODDI metrics computed via AMICO, and a pickle file produced by AMICO:

FIT_ICVF.nii.gz - Relative intracellular volume fraction. Also called neurite
density. It reflects the fraction of the non-isotropic signal that is estimated
to be from intracellular diffusion inside neurites.

FIT_OD.nii.gz - Neurite orientation dispersion about the estimated principal axis.
Normalized to be between 0 (parallel fibers) and 1 (random orientation).

FIT_ISOVF.nii.gz - Isotropic volume fraction. This is the estimated fraction of
the voxel that is occupied by CSF.

FIT_dir.nii.gz - Vector image containing the estimated principal neurite axis in
each voxel.

config.pickle - serialized object produced by AMICO.

## Citations

Accelerated Microstructure Imaging via Convex Optimization (AMICO) from diffusion MRI data Alessandro Daducci, Erick Canales-Rodriguez, Hui Zhang, Tim Dyrby, Daniel C Alexander, Jean-Philippe Thiran NeuroImage 105, pp. 32-44 (2015)

NODDI: practical in vivo neurite orientation dispersion and density imaging of the human brain Hui Zhang, Torben Schneider, Claudia A Wheeler-Kingshott, Daniel C Alexander NeuroImage. 16;61(4):1000-16 (2012)



## Container source

https://github.com/cookpa/amico-noddi