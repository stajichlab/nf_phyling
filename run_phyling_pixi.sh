#!/usr/bin/bash -l
#SBATCH -p batch -c 2 --mem 4gb --out logs/phyling_pixi_nf.log -J phyling_nf
#
# Nextflow driver launcher — pixi-managed conda env + SLURM on UCR HPCC.
#
# Each job activates the project's pixi environment (via `pixi shell-hook` in the
# pixi_slurm profile's beforeScript) to provide its tools, so `pixi` must be on
# PATH on the compute nodes. Submit with:   sbatch run_phyling_pixi.sh
# (create the log dir first:  mkdir -p logs )
#
# Override any setting on the command line, e.g.
#   SEQ_TYPE=cds INPUT=cds PREFIX=mucor_v8 sbatch run_phyling_pixi.sh

# ── Run settings (edit or pass as environment variables) ──────────────
SEQ_TYPE=${SEQ_TYPE:-protein}                                 # protein | cds
INPUT=${INPUT:-pep}                                           # dir of .fa / .fa.gz per taxon
PREFIX=${PREFIX:-my_project}                                  # output base name
MARKERSET=${MARKERSET:-fungi_odb12,mucoromycota_odb12}        # comma-separated BUSCO lineages
OUTDIR=${OUTDIR:-results/${SEQ_TYPE}}

mkdir -p logs

# Make pixi visible to this job and to the per-step beforeScript hooks.
export PATH="${HOME}/.pixi/bin:${PATH}"

# Solve/install the environment once (no-op if already up to date).
pixi install

# Use a site-provided nextflow for the lightweight driver; per-step tools come
# from the pixi env via the pixi_slurm profile.
module load nextflow/26.04.3   # any nextflow >= 24 works; pin to what your site provides

nextflow run main.nf \
    -profile pixi_slurm,ucr_hpcc \
    --seq_type "${SEQ_TYPE}" \
    --input "${INPUT}" \
    --prefix "${PREFIX}" \
    --markerset "${MARKERSET}" \
    --outdir "${OUTDIR}" \
    -resume
