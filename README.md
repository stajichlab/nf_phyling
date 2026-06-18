# PHYling Phylogenomics — Nextflow Pipeline

[![Nextflow](https://img.shields.io/badge/nextflow-%E2%89%A524.0-brightgreen)](https://nextflow.io/)

DSL2 Nextflow pipeline for multi-locus ML phylogenomics using BUSCO single-copy
orthologs. Wraps PHYling, PhyKIT, ModelTest-NG, IQ-TREE 3, RAxML-NG, and
FastTree into two named workflows:

| Workflow | `--seq_type` | Input | Data type | RAxML-NG bootstraps |
|---|---|---|---|---|
| `CDS_TREE` | `cds` | `.fa` per taxon | DNA / CDS | 500 |
| `PROTEIN_TREE` | `protein` | `.fa.gz` per taxon | Amino acid | 100 |

Both workflows run AIC and BIC partition schemes through IQ-TREE and RAxML-NG
in parallel, producing four independently-supported trees per markerset, plus
two FastTreeMP trees (a fast `-nosupport` tree and a `-boot` SH-like support
tree) on the concatenated alignment. IQ-TREE, RAxML-NG, and FastTree are
deliberately independent — one failing never blocks the others.

---

## Pipeline steps

```
INPUT: one sequence file per taxon
         ↓ (per markerset, in parallel)
  phyling download    Fetch BUSCO markerset into ~/.phyling/HMM (skipped if already present)
  phyling align       BUSCO marker search + MSA
  phyling filter      Remove loci below occupancy threshold (default 80% of taxa)
  phyling tree        Per-gene FastTree (exploratory gene trees)
         ↓
  phykit create_concat   Concatenate filtered MSAs; write partition file
  sed AUTO→DNA/PROT       Fix data-type for modeltest-ng
         ↓
  modeltest-ng        Partitioned model selection → AIC and BIC partition files
         ↓          (AIC and BIC run in parallel from here)
  iqtree3 MF+MERGE    Partition merging + ML tree
  iqtree3 UFBoot      Bootstrap (-B 1000 --alrt 1000 --bnni --wbtl)
  raxml-ng --parse    Produce binary alignment; extract thread recommendation
  raxml-ng --all      ML search + bootstraps
  FastTreeMP          Fast approximate-ML tree on the concatenation (single model:
                      -lg / -gtr); one -nosupport tree + one -boot support tree
```

---

## Quick start

### Run directly from GitHub (no clone needed)

```bash
nextflow run stajichlab/phyling-phylogenomics \
  -profile singularity_slurm,ucr_hpcc \
  --seq_type protein \
  --input /path/to/pep \
  --prefix my_project \
  --markerset fungi_odb12,mucoromycota_odb12 \
  --outdir results/pep
```

On UCR HPCC the easiest path is one of the provided sbatch launchers — see
[SLURM batch launchers](#slurm-batch-launchers) below:

```bash
mkdir -p logs
sbatch run_phyling_singularity.sh    # Singularity/BioContainers
sbatch run_phyling_pixi.sh           # pixi-managed conda env
```

### Clone and run locally

```bash
git clone https://github.com/stajichlab/phyling-phylogenomics
cd phyling-phylogenomics

nextflow run main.nf \
  -profile local \
  --seq_type cds \
  --input /path/to/cds \
  --prefix my_project \
  --markerset fungi_odb12 \
  --outdir results/test
```

---

## Requirements

In every case the only tool you need on the machine that launches the run is
**Nextflow (≥ 24)**; the per-step tools are supplied by the chosen software
profile (pixi, Singularity, or environment modules).

### Option A — Singularity / Apptainer (most portable)

Nothing to install beyond Singularity (or Apptainer) and Nextflow — each step
pulls its BioContainers image automatically. Set a shared cache so images aren't
re-pulled per user:

```bash
export NXF_SINGULARITY_CACHEDIR=/bigdata/stajichlab/shared/singularity_cache
```

Use `-profile singularity` (local) or `-profile singularity_slurm` (SLURM).

### Option B — pixi

```bash
# Install pixi if not already present
curl -fsSL https://pixi.sh/install.sh | bash

# Install all pipeline tools
pixi install
```

Tools installed: `nextflow`, `modeltest-ng`, `iqtree ≥2.3` (provides `iqtree3`),
`raxml-ng`, `fasttree` (provides `FastTreeMP`) from bioconda; `phykit` and
`phyling` from PyPI. Use `-profile pixi` (local) or `-profile pixi_slurm` (SLURM).

### Option C — environment modules (HPC)

Module names expected by `-profile modules` (site-specific; UCR HPCC names):
`phyling`, `phykit`, `modeltest-ng`, `iqtree`, `raxml-ng`, `fasttree`

---

## Execution profiles

Profiles compose along two axes — an **executor** (where jobs run) and a
**software** profile (how tools are provided) — combined with commas, plus an
optional **site** profile for queue names. The `*_slurm` profiles are
convenience combinations that bundle the SLURM executor with a software layer.

```
  -profile singularity_slurm,ucr_hpcc   (Singularity + SLURM, UCR queues)
  -profile pixi_slurm,ucr_hpcc          (pixi env + SLURM, UCR queues)
  -profile slurm,modules,ucr_hpcc       (env modules + SLURM, UCR queues)
  -profile singularity                  (Singularity, local executor)
```

| Profile | Executor | Software | Use when |
|---|---|---|---|
| `slurm` | SLURM | — (pair with a software profile) | HPC; the executor only |
| `local` | local | — (tools in PATH) | quick testing |
| `singularity` | local | BioContainers images | local workstation with Singularity |
| `singularity_slurm` | SLURM | BioContainers images | HPC, portable (recommended) |
| `pixi` | local | pixi conda env | local workstation with pixi |
| `pixi_slurm` | SLURM | pixi conda env | HPC without site modules |
| `modules` | — | `module load` per tool | pair with `slurm`; site-specific module names |
| `modules_slurm` | SLURM | `module load` per tool | env-modules HPC shortcut |
| `ucr_hpcc` | — | — | UCR HPCC queue names; combine with any of the above |
| `vm` | local | — | small VM / laptop; caps cpus/memory/time to the machine (combine with a software profile, e.g. `singularity,vm`) |

### Running on a small VM or laptop

Several processes request many cores by default (e.g. `PHYLING_ALIGN` asks for
24). On a machine with fewer CPUs the local executor aborts with
`Process requirement exceeds available CPUs -- req: 24; avail: 4`. The `vm`
profile clamps every process's requested cpus/memory/time down to the machine's
capacity, so those labels fit without editing the pipeline:

```bash
nextflow run stajichlab/nf_phyling \
  -profile singularity,vm \
  --seq_type protein --input pep/ --prefix my_project \
  --markerset fungi_odb12
```

Defaults are 4 cpus / 14 GB / 72 h. Override for your host:

```bash
  -profile singularity,vm --max_cpus 8 --max_memory 30.GB
```

### Using on a different cluster

Queue names are cluster-specific. Create a minimal site config and pass it with `-c`:

```groovy
// my_cluster.config
process {
    withName: 'PHYLING_ALIGN'    { queue = 'bigmem' }
    withName: 'MODELTEST_NG|IQTREE_MF|IQTREE_BOOTSTRAP|RAXMLNG_ALL' { queue = 'compute' }
    withName: 'PHYLING_DOWNLOAD|PHYLING_FILTER|PHYLING_TREE|PHYKIT_CONCAT|RAXMLNG_PARSE' { queue = 'short' }
}
```

```bash
nextflow run stajichlab/phyling-phylogenomics \
  -profile singularity_slurm -c my_cluster.config \
  --seq_type protein --input pep/ --prefix my_project \
  --markerset fungi_odb12
```

---

## SLURM batch launchers

Two ready-to-edit sbatch scripts live in the repository root. They submit a
lightweight Nextflow **driver** job (2 cpus / 4 GB) that in turn dispatches each
pipeline step as its own SLURM job — so the driver must stay alive for the whole
run; keep it on a partition that allows a long wall time.

| Script | Software profile | Tools come from |
|---|---|---|
| `run_phyling_singularity.sh` | `singularity_slurm,ucr_hpcc` | BioContainers images (auto-pulled) |
| `run_phyling_pixi.sh` | `pixi_slurm,ucr_hpcc` | the project's pixi conda env |

Both read their settings from environment variables with sensible defaults, so
you can submit as-is or override per run:

```bash
mkdir -p logs            # the #SBATCH --out path needs this to exist first

# Submit with the built-in defaults (protein, input dir ./pep, prefix my_project)
sbatch run_phyling_singularity.sh

# …or override any setting on the command line
SEQ_TYPE=cds INPUT=cds PREFIX=mucor_v8 \
  MARKERSET=fungi_odb12,mucoromycota_odb12 \
  sbatch run_phyling_singularity.sh

# pixi variant — same knobs
SEQ_TYPE=protein INPUT=pep PREFIX=mucor_v8 sbatch run_phyling_pixi.sh
```

Both pass `-resume`, so re-submitting after an interruption continues from the
last cached step. Settings exposed as variables: `SEQ_TYPE`, `INPUT`, `PREFIX`,
`MARKERSET`, `OUTDIR` (and `NXF_SINGULARITY_CACHEDIR` for the Singularity
launcher). Edit the `#SBATCH` header or the `module load nextflow/...` line to
match your site.

### Singularity image cache

`run_phyling_singularity.sh` sets `NXF_SINGULARITY_CACHEDIR` to a shared lab path
so images are pulled once and reused. If your compute nodes have no outbound
network, pre-pull on a login node, e.g.:

```bash
singularity pull docker://quay.io/biocontainers/fasttree:2.2.0--h7b50bb2_1
```

---

## All parameters

| Parameter | Default | Description |
|---|---|---|
| `--seq_type` | `protein` | Workflow: `cds` or `protein` |
| `--input` | *(required)* | Directory of `.fa` (CDS) or `.fa.gz` (protein) files |
| `--prefix` | *(required)* | Base name for output files, e.g. `my_project_v1` |
| `--markerset` | `fungi_odb12,mucoromycota_odb12` | Comma-separated BUSCO lineage names |
| `--outdir` | `results` | Directory for published outputs |
| `--publish_mode` | `copy` | publishDir mode: `copy`, `link`, or `symlink` |
| `--phyling_db` | `<workDir>/phyling` | Marker DB cache (`$PHYLING_DB`); defaults to a run-local cache under the work folder. Set to a shared path to reuse across runs |
| `--top_n_to_keep` | `80` | Number of top markers to retain (`TOP_N_TOVERR` in phyling filter `-n`) |
| `--rcluster` | `10` | IQ-TREE partition merging aggressiveness |
| `--bs_count` | `1000` | IQ-TREE UFBoot replicates (`-B`) |
| `--alrt_count` | `1000` | IQ-TREE SH-aLRT replicates (`--alrt`) |
| `--pars_trees` | `10` | RAxML-NG parsimony starting trees |
| `--bs_trees_cds` | `500` | RAxML-NG bootstrap replicates for CDS mode |
| `--bs_trees_pep` | `100` | RAxML-NG bootstrap replicates for protein mode |
| `--fasttree_max_cpus` | `8` | FastTreeMP CPU request (OMP threads) |
| `--fasttree_model_prot` | `-lg` | FastTree protein model: `-lg`, `-wag`, or `''` for JTT |
| `--fasttree_model_dna` | `-gtr` | FastTree DNA model: `-gtr`, or `''` for Jukes-Cantor |
| `--fasttree_boot` | `1000` | Resamples for the FastTree SH-like local-support tree |
| `--max_cpus` | `4` | Resource ceiling used only with `-profile vm`: caps every process's requested CPUs |
| `--max_memory` | `14.GB` | Resource ceiling used only with `-profile vm`: caps every process's requested memory |
| `--max_time` | `72.h` | Resource ceiling used only with `-profile vm`: caps every process's requested wall time |

### Common BUSCO markersets

| Markerset | Scope |
|---|---|
| `fungi_odb10` / `fungi_odb12` | All Fungi (ODB10 / ODB12) |
| `mucoromycota_odb10` / `mucoromycota_odb12` | Mucoromycota-specific |
| `basidiomycota_odb10` | Basidiomycota |
| `ascomycota_odb10` | Ascomycota |

Multiple markersets run as independent parallel branches. Each markerset is
fetched automatically by the `PHYLING_DOWNLOAD` step (`phyling download
{markerset}`) before alignment — no manual download is required. Markersets are
cached in `$PHYLING_DB` rather than the default `~/.phyling`; this defaults to a
run-local `<workDir>/phyling` directory, so a clean work folder (or `nextflow
clean`) triggers a re-download. Point `--phyling_db` at a persistent path to
share one cache across runs. Run `phyling download list` to see all available
lineage names.

---

## Example commands

### Protein tree — Singularity + SLURM (UCR HPCC)
```bash
nextflow run stajichlab/phyling-phylogenomics \
  -profile singularity_slurm,ucr_hpcc \
  --seq_type protein \
  --input pep/ \
  --prefix my_project_v1 \
  --markerset fungi_odb12,mucoromycota_odb12 \
  --outdir results/pep
```

### CDS tree — env modules + SLURM (UCR HPCC)
```bash
nextflow run stajichlab/phyling-phylogenomics \
  -profile slurm,modules,ucr_hpcc \
  --seq_type cds \
  --input cds/ \
  --prefix my_project_v1 \
  --markerset fungi_odb12,mucoromycota_odb12 \
  --outdir results/cds
```

### Resume an interrupted run
```bash
nextflow run stajichlab/phyling-phylogenomics -resume \
  -profile singularity_slurm,ucr_hpcc \
  --seq_type protein \
  --input pep/ \
  --prefix my_project_v1 \
  --markerset fungi_odb12,mucoromycota_odb12 \
  --outdir results/pep
```

---

## Output structure

```
results/
└── {cds|pep}/
    ├── align/{markerset}/          phyling align output
    ├── filter/{markerset}/         filtered .mfa files (one per locus)
    ├── tree/{markerset}/           per-gene FastTree trees
    ├── buildtree/{markerset}/
    │   ├── *.fa                    concatenated alignment
    │   ├── *.partition             partition file (data-type fixed)
    │   ├── *.part.aic / *.part.bic ModelTest-NG AIC and BIC schemes
    │   ├── *.aic.bs.treefile       IQ-TREE AIC bootstrap consensus
    │   ├── *.bic.bs.treefile       IQ-TREE BIC bootstrap consensus
    │   ├── *.aic.raxml.support     RAxML-NG AIC support tree
    │   ├── *.bic.raxml.support     RAxML-NG BIC support tree
    │   └── fasttree/
    │       ├── *.fasttree.nosupport.treefile  FastTreeMP tree, support disabled
    │       └── *.fasttree.support.treefile    FastTreeMP tree, SH-like local support
    └── pipeline_info/
        ├── timeline.html
        ├── report.html
        └── dag.svg
```

Tree files (`.treefile`, `.raxml.support`) are Newick format — open in FigTree, iTOL, or ggtree.

---

## Interpreting support values

| Measure | Flag | Strong support threshold |
|---|---|---|
| UFBoot2 (ultrafast bootstrap) | `-B 1000` | ≥ 95 |
| SH-aLRT | `--alrt 1000` | ≥ 80 |
| RAxML-NG bootstrap | `--bs-trees` | ≥ 70 |
| FastTree SH-like local support | `-boot 1000` | ≥ 0.95 (0–1 scale) |

UFBoot values are systematically higher than standard bootstrap — do not compare
directly. FastTree's value is a *local* support, not a full nonparametric
bootstrap, so treat it as a fast sanity check rather than as equivalent to the
RAxML/IQ-TREE numbers. A clade is robustly supported when UFBoot2, SH-aLRT, and
the RAxML-NG bootstrap all exceed their thresholds.

---

## Repository structure

```
phyling-phylogenomics/
├── main.nf                       entry point
├── nextflow.config               params + profiles
├── pixi.toml                     conda/PyPI environment
├── run_phyling_singularity.sh    sbatch launcher (Singularity + SLURM)
├── run_phyling_pixi.sh           sbatch launcher (pixi + SLURM)
├── conf/
│   ├── base.config               per-process resource labels
│   ├── singularity.config        per-process BioContainers images
│   ├── modules.config            per-process `module load` lines (site example)
│   └── ucr_hpcc.config           UCR HPCC queue assignments (site example)
├── workflows/
│   ├── cds_tree.nf
│   └── protein_tree.nf
├── test/fasttree/                standalone FASTTREE smoke test (run_test.sh)
└── modules/local/
    ├── phyling/{download,align,filter,tree}/
    ├── phykit/concat/
    ├── modeltestng/
    ├── iqtree/{mf,bootstrap}/
    ├── fasttree/
    └── raxmlng/{parse,all}/
```

---

## Citation

If you use this pipeline, please cite the underlying tools:

- **PHYling**: Tsai et al. (2026) *G3* jkag062 [https://doi.org/10.1093/g3journal/jkag062](doi:10.1093/g3journal/jkag062)
- **PhyKIT**: Steenwyk et al. (2021) *Bioinformatics* 37:2325–2328 https://doi.org/10.1093/bioinformatics/btab096
- **ModelTest-NG**: Darriba et al. (2020) *Mol Biol Evol* 37:291–294 
- **IQ-TREE 3**: Minh et al. (2020) *Mol Biol Evol* 37:1530–1534
- **RAxML-NG**: Kozlov et al. (2019) *Bioinformatics* 35:4453–4455
- **FastTree 2**: Price et al. (2010) *PLoS ONE* 5:e9490
- **BUSCO**: Manni et al. (2021) *Mol Biol Evol* 38:4647–4654
