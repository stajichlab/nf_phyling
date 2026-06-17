// Full ML search + bootstrapping. The cpu request is driven dynamically by RAxML-NG's own
// recommended thread count (rec_threads), extracted upstream by RAXMLNG_PARSE, clamped to
// [params.raxml_min_cpus, params.raxml_max_cpus]. This makes the SLURM allocation match the
// work instead of requesting a fixed core count. --threads auto{N} then lets RAxML-NG pick the
// optimal count up to that allocation, so it won't oversubscribe (and abort) on small alignments.
process RAXMLNG_ALL {
    tag "${markerset}:${score}"
    label 'process_tree'

    cpus {
        Math.min(
            Math.max((rec_threads as int), params.raxml_min_cpus as int),
            params.raxml_max_cpus as int
        )
    }

    publishDir {
        "${params.outdir}/${params.seq_type}/buildtree/${markerset}/raxmlng"
    }, mode: params.publish_mode

    input:
    tuple val(markerset), val(seq_type), val(score), path(rba), val(rec_threads)
    val bs_trees

    output:
    tuple val(markerset), val(seq_type), val(score), path("*.raxml.bestTree"),  emit: best_tree
    tuple val(markerset), val(seq_type), val(score), path("*.raxml.support"),   emit: support,  optional: true
    path "*.raxml.log",                                                      emit: logs

    script:
    """
    raxml-ng \\
        --all \\
        --msa ${rba} \\
        --threads auto{${task.cpus}} \\
        --tree pars{${params.pars_trees}} \\
        --bs-trees ${bs_trees} \\
        --extra seq-dup-keep
    """
}
