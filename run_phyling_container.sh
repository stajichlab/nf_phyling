#!/usr/bin/bash -l
#SBATCH -p batch -c 2 --mem 4gb --out logs/phyling_container_nf.log -J phyling_nf
#
# Nextflow driver launcher — stajichlab/phyling all-in-one container + SLURM
# on UCR HPCC.
#
# ALTERNATIVE to run_phyling_singularity.sh: instead of one BioContainers
# image per tool, this pulls a single maintained image
# (ghcr.io/stajichlab/phyling) for phyling/phykit/IQ-TREE/RAxML-NG/FastTreeMP;
# ModelTest-NG still comes from its own BioContainers image (not bundled in
# that image). See conf/phyling_container.config for details.
#
# The driver job is light (it only submits and monitors work); the heavy steps
# run as separate SLURM jobs inside the container. Keep this job on a
# partition that allows a long wall time, since it must stay alive for the whole
# run. Submit with:   sbatch run_phyling_container.sh
# (create the log dir first:  mkdir -p logs )
#
# The pipeline is resolved by PROJECT NAME from Nextflow's asset cache, NOT by this
# script's path — sbatch copies the script to a spool dir, so any path derived from
# $BASH_SOURCE/$0 is wrong. `nextflow run <project>` clones/updates the asset itself.
#   PIPELINE   override the source (default: the published GitHub project)
#              - a local checkout for development:  PIPELINE=$PWD sbatch ...
#   REVISION   git branch / tag / commit to run (default: pipeline default branch)
#
# Override any setting on the command line, e.g.
#   SEQ_TYPE=cds INPUT=cds PREFIX=mucor_v8 sbatch run_phyling_container.sh

# ── Run settings (edit or pass as environment variables) ──────────────
PIPELINE=${PIPELINE:-stajichlab/nf_phyling}                   # GitHub project or local checkout dir
REVISION=${REVISION:-}                                        # git branch / tag / commit
SEQ_TYPE=${SEQ_TYPE:-protein}                                 # protein | cds
INPUT=${INPUT:-pep}                                           # dir of .fa / .fa.gz per taxon
PREFIX=${PREFIX:-my_project}                                  # output base name
MARKERSET=${MARKERSET:-fungi_odb12,mucoromycota_odb12}        # comma-separated BUSCO lineages
OUTDIR=${OUTDIR:-results/${SEQ_TYPE}}
PHYLING_IMAGE=${PHYLING_IMAGE:-}                               # override the image tag, e.g. ghcr.io/stajichlab/phyling:2.5.0

# ── Shared image cache so containers aren't re-pulled per user ────────
# If compute nodes lack outbound network, pre-pull on a login node first, e.g.
#   singularity pull docker://ghcr.io/stajichlab/phyling:2.4.1
export NXF_SINGULARITY_CACHEDIR=${NXF_SINGULARITY_CACHEDIR:-/bigdata/stajichlab/shared/singularity_cache}

mkdir -p logs "${NXF_SINGULARITY_CACHEDIR}"

module load singularity
module load nextflow/26.04.3   # any nextflow >= 24 works; pin to what your site provides

nextflow run "${PIPELINE}" ${REVISION:+-r "${REVISION}"} \
    -profile phyling_container_slurm,ucr_hpcc \
    --seq_type "${SEQ_TYPE}" \
    --input "${INPUT}" \
    --prefix "${PREFIX}" \
    --markerset "${MARKERSET}" \
    --outdir "${OUTDIR}" \
    ${PHYLING_IMAGE:+--phyling_image "${PHYLING_IMAGE}"} \
    -resume
