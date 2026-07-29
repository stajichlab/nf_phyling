---
name: phyling-phylogenomics
description: >
  Multi-locus phylogenomics pipeline: PHYling (BUSCO markers) → PhyKIT concat →
  ModelTest-NG → IQ-TREE + RAxML-NG + FastTreeMP. Two workflows: `cds_tree` (DNA)
  and `protein_tree` (AA). Runs on SLURM HPC via modules or pixi. Trigger when
  user wants BUSCO phylogeny, multi-locus tree, partitioned ML analysis, or has
  genomes/proteomes to place in a phylogeny.
---

# PHYling Phylogenomics

Primary pipeline: `/rhome/jstajich/git_lab/phyling-phylogenomics/nextflow/main.nf`
GitHub fallback: `stajichlab/phyling-phylogenomics` (Nextflow fetches automatically)

## Quick-start questions

Ask (or infer) before generating commands:

| Item | Default / notes |
|---|---|
| Mode | `cds_tree` or `protein_tree` |
| Input | `.fa` (CDS) or `.fa.gz` (protein), one file per taxon |
| Prefix | Base name for outputs, e.g. `mucor_jena_v8` |
| Markersets | BUSCO lineages — see below |
| Outdir | `results/cds` or `results/pep` |
| Profile | `slurm,ucr_hpcc` (modules) · `pixi_slurm,ucr_hpcc` · `local` · `pixi` |

## Pipeline flow

```
input → phyling align → phyling filter (--min-taxa-pct, default 80%)
       → phyling tree (per-gene FastTree, exploratory)
       → phykit create_concat → modeltest-ng (AIC + BIC)
         ├─ iqtree3 MF+MERGE → UFBoot (-B 1000 --alrt 1000)
         ├─ raxml-ng --parse → --all (500 bs CDS / 100 bs pep)
         └─ FastTreeMP (single model: -gtr / -lg, two runs: -nosupport + -boot)
```

IQ-TREE, RAxML-NG, FastTree are independent — one failing cannot block others.

## Markersets

Pattern: `{clade}_odb{10|12}`

| Lineage | Scope | Notes |
|---|---|---|
| `fungi_odb12` | All Fungi | **Preferred** for broad phylogeny |
| `fungi_odb10` | All Fungi | Legacy |
| `mucoromycota_odb12` | Mucoromycota | **Preferred** for Mucoromycota-focused |
| `mucoromycota_odb10` | Mucoromycota | Legacy |
| `basidiomycota_odb10` | Basidiomycota | — |
| `ascomycota_odb10` | Ascomycota | — |

**Common combos:** `--markerset fungi_odb12` · `fungi_odb12,mucoromycota_odb12` · `fungi_odb10,fungi_odb12,mucoromycota_odb10,mucoromycota_odb12` (full Mucoromycota protein)

## Execution profiles

| Profile | Executor | Notes |
|---|---|---|
| `slurm` | SLURM | With `module load` per tool |
| `ucr_hpcc` | — | UCR HPCC queues; combine with `slurm` or `pixi_slurm` |
| `pixi` | local | pixi-managed conda env |
| `pixi_slurm` | SLURM | pixi via `pixi shell-hook` |
| `local` | local | Tools must be in PATH |

**UCR HPCC:** `-profile slurm,ucr_hpcc` · **Pixi+SLURM:** `-profile pixi_slurm,ucr_hpcc`

## Commands

### UCR HPCC (modules) — local pipeline

```bash
nextflow run nextflow/main.nf -profile slurm,ucr_hpcc \
  --seq_type cds --input /path/to/cds --prefix PROJ_v1 \
  --markerset fungi_odb12,mucoromycota_odb12 --outdir results/cds

# Protein
nextflow run nextflow/main.nf -profile slurm,ucr_hpcc \
  --seq_type protein --input /path/to/pep --prefix PROJ_v1 \
  --markerset fungi_odb12,mucoromycota_odb12 --outdir results/pep
```

### Pixi + SLURM (UCR HPCC)

```bash
pixi install  # once
pixi run run-pep -- --input /path/to/pep --prefix PROJ_v1 \
  --markerset fungi_odb12 --outdir results/pep -profile pixi_slurm,ucr_hpcc
```

### Custom SLURM cluster

```bash
# Add to nextflow.config or separate file:
# process {
#   withName: 'PHYLING_ALIGN'    { queue = 'bigmem' }
#   withName: 'MODELTEST_NG|...IQTREE...' { queue = 'compute' }
#   withName: 'PHYLING_FILTER|...' { queue = 'short' }
# }
nextflow run stajichlab/nf_phyling -profile slurm -c my_cluster.config \
  --seq_type protein --input /path/to/pep --prefix PROJ_v1 \
  --markerset fungi_odb12 --outdir results/pep
```

### Resume interrupted run

```bash
nextflow run stajichlab/nf_phyling -resume [same flags as original]
```

### Local test

```bash
cd /rhome/jstajich/git_lab/phyling-phylogenomics
nextflow run nextflow/main.nf -profile local \
  --seq_type cds --input /path/to/cds --prefix test \
  --markerset fungi_odb12 --outdir results/test
```

## Key parameters

| Parameter | Default | When to change |
|---|---|---|
| `--top_n_to_keep` | `80` | Lower (60) for sparse datasets |
| `--bs_count` | `1000` | UFBoot replicates — don't go below 1000 |
| `--alrt_count` | `1000` | SH-aLRT replicates |
| `--bs_trees_cds` | `500` | RAxML-NG bootstrap (CDS) |
| `--bs_trees_pep` | `100` | RAxML-NG bootstrap (protein) |
| `--rcluster` | `10` | IQ-TREE partition merging; raise if too slow |
| `--pars_trees` | `10` | RAxML-NG parsimony starting trees (10–25) |
| `--publish_mode` | `copy` | Use `link` on same-filesystem HPC |

## Output structure

```
results/{cds|pep}/
├── align/{markerset}/           phyling align
├── filter/{markerset}/          filtered .mfa files
├── tree/{markerset}/            per-gene FastTree
└── buildtree/{markerset}/
    ├── *.fa                     concatenated alignment
    ├── *.partition              partition file (DNA/PROT fixed)
    ├── *.part.aic / *.part.bic  ModelTest-NG schemes
    ├── *.aic.bs.treefile        IQ-TREE AIC bootstrap consensus
    ├── *.bic.bs.treefile        IQ-TREE BIC bootstrap consensus
    ├── *.aic.raxml.support      RAxML-NG AIC support tree
    ├── *.bic.raxml.support      RAxML-NG BIC support tree
    └── fasttree/
        ├── *.nosupport.treefile
        └── *.support.treefile   (SH-like local support, 0–1 scale)
```

**Primary results:** `*.bs.treefile` and `*.raxml.support` (Newick; view in FigTree/iTOL/ggtree)

## Monitoring & troubleshooting

```bash
tail -f .nextflow.log        # live log
squeue -u $USER              # SLURM jobs
ls work/??/*/                # work directories
cat work/<hash>/.command.log # per-process output
```

| Problem | Solution |
|---|---|
| `phyling align` finds 0 markers | Check input format (`.fa` / `.fa.gz`) and markerset name (`fungi_odb12`, not `fungi12`) |
| `phyling filter` empty | Too few taxa have marker — lower `--top_n_to_keep 60` |
| `phykit concat` fails | Filter step produced no `.mfa` files |
| `modeltest-ng` slow | Normal (12–48h for large datasets on epyc); don't kill |
| IQ-TREE partition error | Check `.partition` file for leftover `AUTO` — should be `DNA`/`PROT` |
| RAxML-NG thread warning | Parse step recommends thread count; pipeline reads `.raxml.log` automatically |

**Always use `-resume`** — Nextflow caches completed processes in `work/`.

## Support interpretation

| Measure | Tool | Threshold |
|---|---|---|
| UFBoot ≥ 95 | IQ-TREE | Strong (note: UFBoot inflated vs standard bootstrap) |
| SH-aLRT ≥ 80 | IQ-TREE | Supported |
| Bootstrap ≥ 70 | RAxML-NG | Robust |
| SH-like 0–1 ≥ 0.95 | FastTreeMP | Fast sanity check only (local support, not equivalent to full bootstrap) |

**Robust clade:** UFBoot, SH-aLRT, and RAxML bootstrap all agree. FastTree is the quick first look.

## Environment (pixi)

```bash
cd /rhome/jstajich/git_lab/phyling-phylogenomics/nextflow
pixi install  # installs: nextflow, modeltest-ng, iqtree3, raxml-ng, FastTreeMP, phykit, phyling
```
