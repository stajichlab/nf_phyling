nextflow.enable.dsl = 2

include { PHYLING_DOWNLOAD  } from '../modules/local/phyling/download/main'
include { PHYLING_ALIGN     } from '../modules/local/phyling/align/main'
include { PHYLING_FILTER    } from '../modules/local/phyling/filter/main'
include { PHYLING_TREE      } from '../modules/local/phyling/tree/main'
include { PHYKIT_CONCAT     } from '../modules/local/phykit/concat/main'
include { MODELTEST_NG      } from '../modules/local/modeltestng/main'
include { IQTREE_MF         } from '../modules/local/iqtree/mf/main'
include { IQTREE_BOOTSTRAP  } from '../modules/local/iqtree/bootstrap/main'
include { RAXMLNG_PARSE     } from '../modules/local/raxmlng/parse/main'
include { RAXMLNG_ALL       } from '../modules/local/raxmlng/all/main'

workflow PROTEIN_TREE {
    def seq_type	     = 'protein'
    def data_type        = 'PROT'
    ch_input_dir  = file(params.input, checkIfExists: true)

    def n_taxa = files("${params.input}/*.fa").size() + 
                files("${params.input}/*.fasta").size() +
                files("${params.input}/*.fna").size() +
                files("${params.input}/*.ffn").size() +
                files("${params.input}/*.fa.gz").size() + 
                files("${params.input}/*.fasta.gz").size() +
                files("${params.input}/*.fna.gz").size() +
                files("${params.input}/*.ffn.gz").size()
    def phykit_stem_base = "${seq_type}-${params.prefix}-taxa_${n_taxa}"

    ch_markersets = Channel.of(params.markerset.tokenize(',')).flatten()

    // ── Step 0: download each markerset into ~/.phyling ────────
    PHYLING_DOWNLOAD(ch_markersets)

    // ── Step 1: align each markerset ──────────────────────────────
    PHYLING_ALIGN(
        PHYLING_DOWNLOAD.out.markerset.map { ms -> [ ms, seq_type, ch_input_dir ] }
    )

    // ── Step 2: filter alignments ─────────────────────────────────
    PHYLING_FILTER(PHYLING_ALIGN.out.align_dir)

    // ── Step 3: per-gene FastTree (runs in parallel with concat) ──
    PHYLING_TREE(PHYLING_FILTER.out.filter_dir)

    // ── Step 4: concatenate filtered MSAs; fix partition data type ─
    // stem per markerset: e.g. pep-mucor_jena_v8.fungi_odb10
    ch_for_concat = PHYLING_FILTER.out.filter_dir.map { ms, m, fdir ->
        [ ms, m, fdir, "${phykit_stem_base}.${ms}" ]
    }
    PHYKIT_CONCAT(ch_for_concat, data_type)

    // ── Step 5: ModelTest-NG partitioned model selection ──────────
    MODELTEST_NG(PHYKIT_CONCAT.out.concat)

    // ── Step 6: split AIC / BIC and run IQ-TREE + RAxML-NG ───────
    ch_aic = MODELTEST_NG.out.partitions.map { ms, m, fa, part_aic, part_bic ->
        [ ms, m, fa, part_aic, 'aic' ]
    }
    ch_bic = MODELTEST_NG.out.partitions.map { ms, m, fa, part_aic, part_bic ->
        [ ms, m, fa, part_bic, 'bic' ]
    }
    ch_scored = ch_aic.mix(ch_bic)

    // RAxML-NG: parse binary + thread advice (cheap, cpus=1). Its recommended thread count
    // also drives the IQ-TREE cpu requests below, so both tree builders share one estimate.
    RAXMLNG_PARSE(ch_scored)

    // (markerset, seq_type, score) -> rec_threads
    ch_rec = RAXMLNG_PARSE.out.parsed.map { ms, st, score, rba, rec -> [ [ms, st, score], rec ] }

    // IQ-TREE: model-finder + merge tree, then UFBoot + SH-aLRT.
    // Join the thread recommendation onto each scored alignment before running.
    ch_iqtree_in = ch_scored
        .map { ms, st, fa, part, score -> [ [ms, st, score], fa, part ] }
        .join(ch_rec)
        .map { key, fa, part, rec -> [ key[0], key[1], fa, part, key[2], rec ] }
    IQTREE_MF(ch_iqtree_in)
    IQTREE_BOOTSTRAP(IQTREE_MF.out.best_scheme)

    // RAxML-NG ML search + bootstraps
    RAXMLNG_ALL(RAXMLNG_PARSE.out.parsed, params.bs_trees_pep)
}
