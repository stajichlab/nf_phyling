// Support: map a set of bootstrap replicate trees onto a reference (best ML) tree to compute
// branch (e.g. Felsenstein bootstrap / TBE) support values. Decouples the support step from
// the ML search so it can be re-run with different bootstrap sets or support metrics.
// Cheap + effectively single-threaded — uses the process_low label.
// Not currently wired into any workflow — provided as a reusable building block.
process RAXMLNG_SUPPORT {
    tag "${markerset}:${score}"
    label 'process_low'

    publishDir {
        "${params.outdir}/${params.seq_type}/buildtree/${markerset}/raxmlng"
    }, mode: params.publish_mode

    input:
    tuple val(markerset), val(seq_type), val(score), path(best_tree), path(bs_trees)

    output:
    tuple val(markerset), val(seq_type), val(score), path("*.raxml.support"), emit: support
    path "*.raxml.log",                                                    emit: logs

    script:
    def prefix = "${markerset}.${score}.support"
    """
    raxml-ng \\
        --support \\
        --tree ${best_tree} \\
        --bs-trees ${bs_trees} \\
        --threads auto{${task.cpus}} \\
        --prefix ${prefix}
    """
}
