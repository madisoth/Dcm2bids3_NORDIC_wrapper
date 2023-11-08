#!/bin/bash -l
#SBATCH -J nordicsbatch
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=80G
#SBATCH -t 3:00:00
#SBATCH -p msismall,msilarge,msibigmem
#SBATCH -o output_logs/nordicsbatch_%A_%a.out
#SBATCH -e output_logs/nordicsbatch_%A_%a.err
#SBATCH -A faird

module load matlab/R2019a
module load fsl/5.0.10

# usage: sbatch nordicsbatch.sh <phase src> <phase dst> <num noise volumes>

# positional arguments (all are required)
# $1 = src phase file (dcm2bids3 post_op "src_file", in the tmp_dcm2bids dir )
# $2 = dst phase file (dcm2bids3 post_op "dst_file", filename must contain "_part-phase_", and a matching "_part-mag_" timeseries must exist in the same dir)
# $3 = number of noise volumes in the input file

# optional arguments
# --keep-non-nordic: flag to keep (with noise volumes removed) the non-NORDIC denoised magnitude timeseries after the NORDIC-denoised timeseries is produced

# outputs: 
# NORDIC-processed magnitude timeseries (with noise volumes removed) and json sidecar
# If successful, the input phase and magnitude timeseries and sidecars are removed

PHASE_SRC=$1
PHASE_DST=$2
NOISEVOLS=$3

keep_non_nordic=false

# Check if there are arguments to parse
if [[ $# -gt 0 ]]; then
  # Enter the loop if there are arguments
  while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
      --keep-non-nordic)
        keep_non_nordic=true
        shift
        ;;
      *)
        # Handle any other arguments or options here if needed
        shift
        ;;
    esac
  done
else
  echo "No arguments provided to parse."
fi

# copy phase from dcm2bids tmp dir to BIDS dir
cp ${PHASE_SRC} ${PHASE_DST}

# get paths for input mag timeseries, outputs, and work dir
MAG=`echo ${PHASE_DST} | sed -e s/_part-phase_/_part-mag_/`
NORDIC=`echo ${MAG} | sed -e s/_part-mag_/_/`
NONORDIC=`echo ${MAG} | sed -e s/_part-mag_/_/ | sed -E 's/_task-([^_]*)_/_task-\1NoNORDIC_/'` 
NORDICHEAD=`basename $(echo ${NORDIC} | sed -e s/.nii.gz//)`
WD=`dirname $(readlink -f ${PHASE_DST})`

echo "WD: ${WD}"
echo "MAG: ${MAG}"
echo "PHASE_SRC: ${PHASE_SRC}"
echo "PHASE_DST: ${PHASE_DST}"
echo "NORDICHEAD: ${NORDICHEAD}"
if [[ "$keep_non_nordic" = true ]] ; then
    echo "NONORDIC: ${NONORDIC}"
fi
echo "NOISEVOLS: ${NOISEVOLS}"

# run NORDIC Matlab script
echo matlab -nodisplay -nodesktop -r "addpath('/home/faird/shared/code/internal/utilities/Dcm2bids3_NORDIC_wrapper'); runnordic('$WD','$MAG','$PHASE_DST','$NORDICHEAD',$NOISEVOLS)"
matlab -nodisplay -nodesktop -r "addpath('/home/faird/shared/code/internal/utilities/Dcm2bids3_NORDIC_wrapper'); runnordic('$WD','$MAG','$PHASE_DST','$NORDICHEAD',$NOISEVOLS)"

# gzip output
echo gzip ${WD}/${NORDICHEAD}.nii 
gzip ${WD}/${NORDICHEAD}.nii 

# copy sidecar
echo cp ${MAG::-7}.json ${WD}/${NORDICHEAD}.json
cp ${MAG::-7}.json ${WD}/${NORDICHEAD}.json

# get new number of volumes after noise volume removal 
NVOLS=`fslinfo ${WD}/${NORDICHEAD}.nii.gz | grep -w dim4 | awk '{print $2}'`
NEWVOLS=`echo "${NVOLS} - ${NOISEVOLS}" | bc`

# remove noise volumes
echo "removing ${NOISEVOLS} noise volumes from NORDIC timeseries..."
fslroi ${WD}/${NORDICHEAD}.nii.gz ${WD}/${NORDICHEAD}.nii.gz 0 $NEWVOLS

if [[ "$keep_non_nordic" = true ]] ; then
    echo "removing ${NOISEVOLS} noise volumes from non-NORDIC..."
    fslroi ${MAG} ${NONORDIC} 0 $NEWVOLS
    cp ${MAG::-7}.json ${NONORDIC::-7}.json
fi

# cleanup
if [ -e "${WD}/${NORDICHEAD}.nii.gz" ]; then
    echo "cleaning up..."
    rm ${MAG::-7}*
    rm ${PHASE_DST::-7}*
    echo "...done!"
else
    echo "expected output ${WD}/${NORDICHEAD}.nii.gz does not exist."
fi
