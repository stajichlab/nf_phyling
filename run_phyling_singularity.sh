#!/usr/bin/bash -l
#SBATCH -p batch -c 2 --mem 4gb --out logs/phyling_singularity_nf.log -J phyling_nf
#
# Nextflow driver launcher — Singularity/BioContainers + SLURM on UCR HPCC.
#
# The driver job is light (it only submits and monitors work); the heavy steps
# run as separate SLURM jobs inside BioContainers images. Keep this job on a
# partition that allows a long wall time, since it must stay alive for the whole
# run. Submit with:   sbatch run_phyling_singularity.sh
# (create the log dir first:  mkdir -p logs )
#
# Override any setting on the command line, e.g.
#   SEQ_TYPE=cds INPUT=cds PREFIX=mucor_v8 sbatch run_phyling_singularity.sh

# ── Run settings (edit or pass as environment variables) ──────────────
SEQ_TYPE=${SEQ_TYPE:-protein}                                 # protein | cds
INPUT=${INPUT:-pep}                                           # dir of .fa / .fa.gz per taxon
PREFIX=${PREFIX:-my_project}                                  # output base name
MARKERSET=${MARKERSET:-fungi_odb12,mucoromycota_odb12}        # comma-separated BUSCO lineages
OUTDIR=${OUTDIR:-results/${SEQ_TYPE}}

# ── Shared image cache so containers aren't re-pulled per user ────────
# If compute nodes lack outbound network, pre-pull on a login node first, e.g.
#   singularity pull docker://quay.io/biocontainers/fasttree:2.2.0--h7b50bb2_1
export NXF_SINGULARITY_CACHEDIR=${NXF_SINGULARITY_CACHEDIR:-/bigdata/stajichlab/shared/singularity_cache}

mkdir -p logs "${NXF_SINGULARITY_CACHEDIR}"

module load singularity
module load nextflow/26.04.3   # any nextflow >= 24 works; pin to what your site provides

nextflow run main.nf \
    -profile singularity_slurm,ucr_hpcc \
    --seq_type "${SEQ_TYPE}" \
    --input "${INPUT}" \
    --prefix "${PREFIX}" \
    --markerset "${MARKERSET}" \
    --outdir "${OUTDIR}" \
    -resume
