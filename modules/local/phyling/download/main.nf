process PHYLING_DOWNLOAD {
    tag "${markerset}"
    label 'process_short'

    input:
    val markerset

    output:
    val markerset, emit: markerset

    script:
    def db = params.phyling_db ?: "${workflow.workDir}/phyling"
    """
    # phyling reads/writes markersets under \$PHYLING_DB (a local cache here
    # instead of the default \$HOME/.phyling); align resolves it via `-m ${markerset}`.
    # The dir must exist and be writable or phyling falls back to \$HOME/.phyling.
    export PHYLING_DB="${db}"
    mkdir -p "\$PHYLING_DB"

    # only fetch if it isn't already present in the cache
    if [ ! -d "\$PHYLING_DB/${markerset}" ]; then
        phyling download ${markerset} --verbose
    else
        echo "markerset ${markerset} already present in \$PHYLING_DB, skipping download"
    fi
    """
}
