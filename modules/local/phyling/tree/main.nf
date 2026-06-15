process PHYLING_TREE {
    tag "${markerset}"
    label 'process_medium'

    publishDir { "${params.outdir}/${params.seq_type}/tree" }, mode: params.publish_mode

    input:
    tuple val(markerset), val(seq_type), path(filter_dir)

    output:
    tuple val(markerset), val(seq_type), path("${markerset}"), emit: tree_dir

    script:
    def db = params.phyling_db ?: "${workflow.workDir}/phyling"
    """
    export PHYLING_DB="${db}"
    mkdir -p "\$PHYLING_DB"

    phyling tree \\
        -I ${filter_dir} \\
        -M ft \\
        -t ${task.cpus} \\
        -o ${markerset} \\
        --verbose
    """
}
