// Model selection + tree search with partition merging.
// Runs once per (markerset, score) combination.
process IQTREE_MF {
    tag "${markerset}:${score}"
    label 'process_tree'
    
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
        --ntmax ${task.cpus}
    """
}
