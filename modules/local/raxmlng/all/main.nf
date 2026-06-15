// Full ML search + bootstrapping. Reads recommended thread count from parse log.
process RAXMLNG_ALL {
    tag "${markerset}:${score}"
    label 'process_tree'

    publishDir { 
        "${params.outdir}/${params.seq_type}/buildtree/${markerset}/raxmlng"
    }, mode: params.publish_mode

    input:
    tuple val(markerset), val(seq_type), val(score), path(rba), path(raxml_log)
    val bs_trees

    output:
    tuple val(markerset), val(seq_type), val(score), path("*.raxml.bestTree"),  emit: best_tree
    tuple val(markerset), val(seq_type), val(score), path("*.raxml.support"),   emit: support,  optional: true
    path "*.raxml.log",                                                      emit: logs

    script:
    """
    CPURUN=\$(grep 'Recommended number of threads' ${raxml_log} | cut -d: -f2 | tail -n1 | awk '{print \$1}')
    CPURUN=\${CPURUN:-${task.cpus}}

    raxml-ng \\
        --all \\
        --msa ${rba} \\
        --threads auto{\$CPURUN} \\
        --tree pars{${params.pars_trees}} \\
        --bs-trees ${bs_trees}
    """
}
