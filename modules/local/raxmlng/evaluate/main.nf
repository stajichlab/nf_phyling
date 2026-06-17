// Evaluate: re-optimize model parameters + branch lengths on a FIXED tree topology.
// Useful for scoring an externally-supplied tree (e.g. a constraint or competing topology)
// under the same model without re-searching. The .rba binary from RAXMLNG_PARSE already
// carries the model, so no separate --model is needed.
// Not currently wired into any workflow — provided as a reusable building block.
// cpu request mirrors RAXMLNG_ALL: driven by RAxML-NG's recommended thread count (rec_threads),
// clamped to [params.raxml_min_cpus, params.raxml_max_cpus].
process RAXMLNG_EVALUATE {
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
    tuple val(markerset), val(seq_type), val(score), path(rba), path(tree), val(rec_threads)

    output:
    tuple val(markerset), val(seq_type), val(score), path("*.raxml.bestTree"),  emit: best_tree
    tuple val(markerset), val(seq_type), val(score), path("*.raxml.bestModel"), emit: best_model, optional: true
    path "*.raxml.log",                                                      emit: logs

    script:
    def prefix = "${markerset}.${score}.eval"
    """
    raxml-ng \\
        --evaluate \\
        --msa ${rba} \\
        --tree ${tree} \\
        --threads auto{${task.cpus}} \\
        --prefix ${prefix}
    """
}
