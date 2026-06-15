process PHYLING_ALIGN {
    tag "${markerset}"
    label 'process_high_memory'

    publishDir { "${params.outdir}/${seq_type}/align" }, mode: params.publish_mode

    input:
    tuple val(markerset), val(seq_type), path(input_dir)

    output:
    tuple val(markerset), val(seq_type), path("${markerset}-align"), emit: align_dir

    script:
    def seqtype_arg = seq_type == 'cds' ? '--seqtype dna' : ''
    def db = params.phyling_db ?: "${workflow.workDir}/phyling"
    """
    # resolve the markerset from the shared local cache populated by PHYLING_DOWNLOAD
    export PHYLING_DB="${db}"
    mkdir -p "\$PHYLING_DB"

    phyling align \\
        -I ${input_dir} \\
        -m ${markerset} \\
        -o ${markerset}-align \\
        -t ${task.cpus} \\
        --verbose \\
        ${seqtype_arg}

    """
}
