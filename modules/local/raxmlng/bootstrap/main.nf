// Bootstrap: generate a set of bootstrap replicate trees (no ML search on the original MSA).
// The resulting *.raxml.bootstraps file is the input to RAXMLNG_SUPPORT, letting the bootstrap
// and support stages be split apart and re-run independently of the ML search (RAXMLNG_ALL).
// The .rba binary from RAXMLNG_PARSE carries the model, so no separate --model is needed.
// Not currently wired into any workflow — provided as a reusable building block.
// cpu request mirrors RAXMLNG_ALL: driven by RAxML-NG's recommended thread count (rec_threads),
// clamped to [params.raxml_min_cpus, params.raxml_max_cpus]. --threads auto{N} then lets RAxML-NG
// pick the optimal count up to that allocation, so it never oversubscribes the cores/alignment.
process RAXMLNG_BOOTSTRAP {
    tag "${markerset}:${score}"
    label 'process_tree'

    cpus {
        Math.min(
            Math.max((rec_threads as int), params.raxml_min_cpus as int),
            params.raxml_max_cpus as int
        )
    }

    publishDir {
        "${params.outdir}/${params.seq_type}/buildtree/${markerset}/raxmlng"
    }, mode: params.publish_mode

    input:
    tuple val(markerset), val(seq_type), val(score), path(rba), val(rec_threads)
    val bs_trees

    output:
    tuple val(markerset), val(seq_type), val(score), path("*.raxml.bootstraps"), emit: bootstraps
    path "*.raxml.log",                                                       emit: logs

    script:
    def prefix = "${markerset}.${score}.bs"
    """
    raxml-ng \\
        --bootstrap \\
        --msa ${rba} \\
        --bs-trees ${bs_trees} \\
        --threads auto{${task.cpus}} \\
        --prefix ${prefix} \\
        --extra seq-dup-keep
    """
}
