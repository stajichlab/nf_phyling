// Model selection + tree search with partition merging.
// Runs once per (markerset, score) combination.
// The cpu request is driven by rec_threads (RAxML-NG's recommended thread count for this same
// alignment, computed by RAXMLNG_PARSE), clamped to [params.iqtree_min_cpus, params.iqtree_max_cpus].
// -T AUTO still lets IQ-TREE scale down within that allocation.
process IQTREE_MF {
    tag "${markerset}:${score}"
    label 'process_tree'

    cpus {
        Math.min(
            Math.max((rec_threads as int), params.iqtree_min_cpus as int),
            params.iqtree_max_cpus as int
        )
    }

    publishDir {
        "${params.outdir}/${params.seq_type}/buildtree/${markerset}/iqtree"
    }, mode: params.publish_mode

    input:
    tuple val(markerset), val(seq_type), path(concat_fa), path(partition), val(score), val(rec_threads)


    output:
    tuple val(markerset), val(seq_type), val(score), path(concat_fa), path("*.best_scheme.nex"), val(rec_threads), emit: best_scheme
    tuple val(markerset), val(seq_type), val(score), path("*.treefile"),                         emit: treefile, optional: true
    path "*.log",                                                                             emit: logs,    optional: true

    script:
    def prefix = "${concat_fa.baseName}.${score}"
    """
    iqtree3 \\
        -s ${concat_fa} \\
        -p ${partition} \\
        -m MF+MERGE \\
        -rcluster ${params.rcluster} \\
        --prefix ${prefix} \\
        -T AUTO \\
        --threads-max ${task.cpus}
    """
}
