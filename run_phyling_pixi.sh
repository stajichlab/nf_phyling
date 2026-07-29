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
# The pipeline is resolved by PROJECT NAME from Nextflow's asset cache, NOT by this
# script's path — sbatch copies the script to a spool dir, so any path derived from
# $BASH_SOURCE/$0 is wrong. `nextflow run <project>` clones/updates the asset itself,
# and the pixi env is installed against THAT checkout's pixi.toml (matching the
# pixi_slurm profile's `--manifest-path ${projectDir}/pixi.toml`).
#   PIPELINE   override the source (default: the published GitHub project)
#              - a local checkout for development:  PIPELINE=$PWD sbatch ...
#   REVISION   git branch / tag / commit to run (default: pipeline default branch)
#
# Override any setting on the command line, e.g.
#   SEQ_TYPE=cds INPUT=cds PREFIX=mucor_v8 sbatch run_phyling_pixi.sh

# ── Run settings (edit or pass as environment variables) ──────────────
PIPELINE=${PIPELINE:-stajichlab/nf_phyling}                   # GitHub project or local checkout dir
REVISION=${REVISION:-}                                        # git branch / tag / commit
SEQ_TYPE=${SEQ_TYPE:-protein}                                 # protein | cds
INPUT=${INPUT:-pep}                                           # dir of .fa / .fa.gz per taxon
PREFIX=${PREFIX:-my_project}                                  # output base name
MARKERSET=${MARKERSET:-fungi_odb12,mucoromycota_odb12}        # comma-separated BUSCO lineages
OUTDIR=${OUTDIR:-results/${SEQ_TYPE}}

mkdir -p logs

# Make pixi visible to this job and to the per-step beforeScript hooks.
export PATH="${HOME}/.pixi/bin:${PATH}"

# Use a site-provided nextflow for the lightweight driver; per-step tools come
# from the pixi env via the pixi_slurm profile.
module load nextflow/26.04.3   # any nextflow >= 24 works; pin to what your site provides

# Resolve the pipeline checkout so we install the env against the SAME pixi.toml the
# pipeline runs from. A local dir is used as-is; a project name is pulled into the
# asset cache (deterministic path: $NXF_HOME/assets/<project>).
if [ -d "${PIPELINE}" ]; then
    PROJECT_DIR="${PIPELINE}"
else
    nextflow pull "${PIPELINE}" ${REVISION:+-r "${REVISION}"}
    PROJECT_DIR="${NXF_HOME:-${HOME}/.nextflow}/assets/${PIPELINE}"
fi

# Solve/install the environment once (no-op if already up to date).
pixi install --manifest-path "${PROJECT_DIR}/pixi.toml"

nextflow run "${PIPELINE}" ${REVISION:+-r "${REVISION}"} \
    -profile pixi_slurm,ucr_hpcc \
    --seq_type "${SEQ_TYPE}" \
    --input "${INPUT}" \
    --prefix "${PREFIX}" \
    --markerset "${MARKERSET}" \
    --outdir "${OUTDIR}" \
    -resume
