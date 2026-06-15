process MODELTEST_NG {
    tag "${markerset}"
    label 'process_high'

    publishDir { 
        "${params.outdir}/${params.seq_type}/buildtree/${markerset}/modeltest"
    }, mode: params.publish_mode

    input:
    tuple val(markerset), val(seq_type), path(concat_fa), path(partition)

    output:
    tuple val(markerset), val(seq_type), path(concat_fa), path("${concat_fa}.part.aic"), path("${concat_fa}.part.bic"), emit: partitions
    path "*.log", emit: logs

    script:
    """
    modeltest-ng \\
        -i ${concat_fa} \\
        -q ${partition} \\
        --processes ${task.cpus} \\
        -T raxml
    """
}
