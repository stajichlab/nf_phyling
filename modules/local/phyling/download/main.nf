process PHYLING_DOWNLOAD {
    tag "${markerset}"
    label 'process_short'

    input:
    val markerset

    output:
    val markerset, emit: markerset

    script:
    """
    # phyling stores the markerset under the config folder \$HOME/.phyling
    # align resolves it from there via `-m ${markerset}`
    # only fetch if it isn't already present locally
    if [ ! -d "\${HOME}/.phyling/${markerset}" ]; then
        phyling download ${markerset} --verbose
    else
        echo "markerset ${markerset} already present in \${HOME}/.phyling, skipping download"
    fi
    """
}
