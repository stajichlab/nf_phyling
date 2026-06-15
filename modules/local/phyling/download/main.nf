process PHYLING_DOWNLOAD {
    tag "${markerset}"
    label 'process_short'

    input:
    val markerset

    output:
    tuple val(markerset), path("${markerset}_hmm"), emit: hmm_dir

    script:
    """
    # phyling stores the markerset under the config folder \$HOME/.phyling
    phyling download ${markerset} --verbose

    # stage the downloaded markerset into the task work dir so it is an
    # explicit, cacheable pipeline input for the align step
    cp -rL "\${HOME}/.phyling/${markerset}" "${markerset}_hmm"
    """
}
