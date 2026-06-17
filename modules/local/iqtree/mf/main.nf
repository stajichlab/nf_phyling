// Model selection + tree search with partition merging.
// Runs once per (markerset, score) combination.
// Independent of RAxML-NG: requests params.iqtree_max_cpus and lets -T AUTO scale down within
// that allocation, so a raxml-ng failure can never block this step.
process IQTREE_MF {
    tag "${markerset}:${score}"
    label 'process_tree'

    cpus { params.iqtree_max_cpus as int }

    publishDir {
        "${params.outdir}/${params.seq_type}/buildtree/${markerset}/iqtree"
    }, mode: params.publish_mode

    input:
    tuple val(markerset), val(seq_type), path(concat_fa), path(partition), val(score)


    output:
    tuple val(markerset), val(seq_type), val(score), path(concat_fa), path("*.best_scheme.nex"), emit: best_scheme
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
