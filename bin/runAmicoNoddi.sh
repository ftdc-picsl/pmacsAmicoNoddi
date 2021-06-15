#!/bin/bash -e

cleanup=1

scriptPath=$(readlink -f "$0")
scriptDir=$(dirname "${scriptPath}")
# Repo base dir under which we find bin/ and containers/
repoDir=${scriptDir%/bin}

function usage() {
  echo "Usage:
  $0 [-h] [-c 1/0] \\
    -v containerVersion -i /path/to/data/dwi -m /path/to/mask.nii.gz -o /path/to/output/outputFilePrefix [ -- [container args] ]

  Additional args may be passed to the container after terminating script args with '--'.
"
}

function help() {
    usage
  echo "

Required args:

  -i
    Input absolute path to DWI data where /path/to/data/dwi.[nii.gz, bval, bvec] exists.

  -m
    Brain mask image.

  -o
    Output absolute path on the local file system, including file prefix.

  -v version
     container version to run. The script will look for containers/amico-noddi-[version].sif.


Options:

  -c 1/0
     Cleanup the working dir after running the prep (default = $cleanup).

  -h
     Prints this help message.


Output:

NODDI metrics computed via AMICO, and a pickle file produced by AMICO:

  * FIT_ICVF.nii.gz
  * FIT_OD.nii.gz
  * FIT_ISOVF.nii.gz
  * FIT_dir.nii.gz
  * config.pickle

See README or container website for more information and citations

https://github.com/cookpa/amico-noddi

"
}

if [[ $# -eq 0 ]]; then
  usage
  exit 1
fi

containerVersion=""
inputRoot=""
mask=""
outputRoot=""

while getopts "c:i:m:o:v:h" opt; do
  case $opt in
    c) cleanup=$OPTARG;;
    h) help; exit 1;;
    i) inputRoot=$OPTARG;;
    m) mask=$OPTARG;;
    o) outputRoot=$OPTARG;;
    v) containerVersion=$OPTARG;;
    \?) echo "Unknown option $OPTARG"; exit 2;;
    :) echo "Option $OPTARG requires an argument"; exit 2;;
  esac
done

shift $((OPTIND-1))

amicoUserArgs="$*"

image="${repoDir}/containers/amico-noddi-${containerVersion}.sif"

if [[ ! -f "$image" ]]; then
  echo "Cannot find requested container $image"
  exit 1
fi

if [[ -z "${LSB_JOBID}" ]]; then
  echo "This script must be run within a (batch or interactive) LSF job"
  exit 1
fi

sngl=$( which singularity ) ||
    ( echo "Cannot find singularity executable. Try module load DEV/singularity"; exit 1 )

if [[ ! -f "${inputRoot}.nii.gz" ]]; then
  echo "Cannot find DWI data ${inputRoot}.nii.gz"
  exit 1
fi

# Get input dir to mount into the container as /data/dwi
inputDir=$(dirname "$(readlink -f "${inputRoot}")")
inputFileRoot=$(basename "$(readlink -f "${inputRoot}")")

if [[ ! -f "${mask}" ]]; then
  echo "Cannot find brain mask $mask"
  exit 1
fi

maskDir=$(dirname "$(readlink -e "${mask}")")
maskFile=$(basename "$(readlink -e "${mask}")")

outputDir=$(dirname "$(readlink -m "${outputRoot}")")
outputFileRoot=$(basename "$(readlink -m "${outputRoot}")")

if [[ ! -d "${outputDir}" ]]; then
  mkdir -p "$outputDir"
fi

if [[ ! -d "${outputDir}" ]]; then
  echo "Could not find or create output directory ${outputDir}"
  exit 1
fi

# Set a job-specific temp dir
jobTmpDir=$( mktemp -d -p ${SINGULARITY_TMPDIR} amicoNODDI.${LSB_JOBID}.XXXXXXXX.tmpdir ) ||
    ( echo "Could not create job temp dir ${jobTmpDir}"; exit 1 )

# module DEV/singularity sets SINGULARITYENV_TMPDIR=/scratch
# We make a temp dir there and bind to /tmp in the container
export SINGULARITYENV_TMPDIR="/tmp"

# singularity args
singularityArgs="--cleanenv \
  -B ${jobTmpDir}:/tmp \
  -B ${inputDir}:/data/input \
  -B ${maskDir}:/data/mask \
  -B ${outputDir}:/data/output"

echo "
--- Script options ---
Container image        : $image
Input DWI prefix       : $inputRoot
Brain mask             : $mask
Output prefix          : $outputRoot
Cleanup temp           : $cleanup
---
"

echo "
--- Container details ---"
singularity inspect $image
echo "---
"

cmd="singularity run \
  $singularityArgs \
  $image \
  --dwi-root /data/input/${inputFileRoot} \
  --brain-mask /data/mask/${maskFile} \
  --output-root /data/output/${outputFileRoot} \
  ${amicoUserArgs}
  "

echo "
--- amico-noddi command ---
$cmd
---
"

($cmd)
singExit=$?

if [[ $singExit -ne 0 ]]; then
  echo "Container exited with non-zero code $singExit"
fi

if [[ $cleanup -eq 1 ]]; then
  echo "Removing temp dir ${jobTmpDir}"
  rm -rf ${jobTmpDir}
else
  echo "Leaving temp dir ${jobTmpDir}"
fi

exit $singExit
