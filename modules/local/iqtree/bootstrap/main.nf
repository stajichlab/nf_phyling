// UFBoot2 + SH-aLRT bootstraps using the best partitioning scheme from IQTREE_MF.
// cpu request driven by rec_threads carried through from IQTREE_MF (see that module for details).
process IQTREE_BOOTSTRAP {
    tag "${markerset}:${score}"
    label 'process_tree'

    cpus {
        Math.min(
            Math.max((rec_threads as int), params.iqtree_min_cpus as int),
            params.iqtree_max_cpus as int
        )
    }

    publishDir {
        "${params.outdir}/${params.seq_type}/buildtree/${markerset}/iqtree"
    }, mode: params.publish_mode

    input:
    tuple val(markerset), val(seq_type), val(score), path(concat_fa), path(best_scheme), val(rec_threads)

    output:
    tuple val(markerset), val(seq_type), val(score), path("*.treefile"), emit: treefile
    tuple val(markerset), val(seq_type), val(score), path("*.contree"),  emit: contree,  optional: true
    path "*.log",                                                     emit: logs,    optional: true

    script:
    def prefix = "${concat_fa.baseName}.${score}.bs"
    """
    iqtree3 \\
        -s ${concat_fa} \\
        -p ${best_scheme} \\
        -B ${params.bs_count} \\
        --alrt ${params.alrt_count} \\
        --bnni \\
        --wbtl \\
        --prefix ${prefix} \\
        -T AUTO \\
        --ntmax ${task.cpus}
    """
}
