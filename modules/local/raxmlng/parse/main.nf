// Parse alignment + partition to produce a binary .rba and get thread recommendation.
process RAXMLNG_PARSE {
    tag "${markerset}:${score}"
    label 'process_low'

    publishDir {
        "${params.outdir}/${params.seq_type}/buildtree/${markerset}/raxmlng"
    }, mode: params.publish_mode

    input:
    tuple val(markerset), val(seq_type), path(concat_fa), path(partition), val(score)

    output:
    // REC_THREADS = RAxML-NG's own recommended thread count, parsed from the log so it can
    // drive the downstream RAXMLNG_ALL cpu request (see modules/local/raxmlng/all/main.nf).
    tuple val(markerset), val(seq_type), val(score), path("${stem}.raxml.rba"), env('REC_THREADS'), emit: parsed
    path "${stem}.raxml.log", emit: log

    script:
    stem = "${concat_fa.baseName}.${score}"
    """
    raxml-ng \\
        --parse \\
        --msa ${concat_fa} \\
        --model ${partition} \\
        --prefix ${stem}

    # "Recommended number of threads / MPI processes: N for this alignment"
    REC_THREADS=\$(grep 'Recommended number of threads' ${stem}.raxml.log | grep -oE '[0-9]+' | head -n1)
    REC_THREADS=\${REC_THREADS:-${params.raxml_min_cpus}}
    """
}
