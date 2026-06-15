process PHYLING_FILTER {
    tag "${markerset}"
    label 'process_medium'

    publishDir { "${params.outdir}/${seq_type}/filter" }, mode: params.publish_mode

    input:
    tuple val(markerset), val(seq_type), path(align_dir)

    output:
    tuple val(markerset), val(seq_type), path("${markerset}-filter"), emit: filter_dir

    script:
    """
    phyling filter \\
        -I ${align_dir} \\
        -t ${task.cpus} \\
        -o ${markerset}-filter \\
        --verbose \\
        -n ${params.top_n_to_keep}
    """
}
