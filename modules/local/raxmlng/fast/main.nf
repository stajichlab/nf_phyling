// Fast: quick ML tree search. `--fast` is a raxml-ng alias for
//   --search --tree pars{1} --opt-topology simplified --stop-rule kh-mult
// i.e. a single parsimony start tree with a simplified topology-optimization heuristic.
// Good for a fast exploratory topology; not a substitute for the thorough RAXMLNG_ALL search.
// The .rba binary from RAXMLNG_PARSE carries the model, so no separate --model is needed.
// Not currently wired into any workflow — provided as a reusable building block.
// cpu request mirrors RAXMLNG_ALL: driven by RAxML-NG's recommended thread count (rec_threads),
// clamped to [params.raxml_min_cpus, params.raxml_max_cpus].
process RAXMLNG_FAST {
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

    output:
    tuple val(markerset), val(seq_type), val(score), path("*.raxml.bestTree"),  emit: best_tree
    tuple val(markerset), val(seq_type), val(score), path("*.raxml.bestModel"), emit: best_model, optional: true
    path "*.raxml.log",                                                      emit: logs

    script:
    def prefix = "${markerset}.${score}.fast"
    """
    raxml-ng \\
        --fast \\
        --msa ${rba} \\
        --threads auto{${task.cpus}} \\
        --prefix ${prefix} \\
        --extra seq-dup-keep
    """
}
