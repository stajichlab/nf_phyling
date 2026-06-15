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
    tuple val(markerset), val(seq_type), val(score), path("${stem}.raxml.rba"), path("${stem}.raxml.log"), emit: parsed

    script:
    stem = "${concat_fa.baseName}.${score}"
    """
    raxml-ng \\
        --parse \\
        --msa ${concat_fa} \\
        --model ${partition} \\
        --prefix ${stem}
    """
}
