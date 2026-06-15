process PHYLING_ALIGN {
    tag "${markerset}"
    label 'process_high_memory'

    publishDir { "${params.outdir}/${params.seq_type}/align" }, mode: params.publish_mode

    input:
    tuple val(markerset), val(seq_type), path(input_dir), path(hmm_dir)

    output:
    tuple val(markerset), val(seq_type), path("${markerset}"), emit: align_dir

    script:
    """
    phyling align \\
        -I ${input_dir} \\
        -m ${hmm_dir} \\
        -o ${markerset} \\
        -t ${task.cpus} \\
        --verbose
    """
}
