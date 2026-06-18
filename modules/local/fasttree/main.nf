// FastTreeMP ML tree on the concatenated alignment.
//
// A fast, approximate-ML third tree builder, run alongside IQ-TREE and RAxML-NG.
// FastTree cannot use ModelTest-NG's partitioned models — it applies a single
// substitution model across the whole alignment — so it runs straight off the
// concatenated MSA (one tree per markerset) rather than per AIC/BIC scheme, and is
// deliberately independent of every modeltest / iqtree / raxml step.
//
// Produces two trees from the same alignment:
//   * .nosupport.treefile — branch support turned off (-nosupport), fastest.
//   * .support.treefile   — FastTree SH-like local support from -boot resamples.
//     NOTE: these are SH-like local supports computed by reusing the per-site
//     likelihoods, not full nonparametric bootstraps like RAxML-NG's; don't
//     compare the numbers directly to RAxML/IQ-TREE bootstrap values.
//
// Multithreading comes from the OpenMP build (FastTreeMP) via OMP_NUM_THREADS.
process FASTTREE {
    tag "${markerset}"
    label 'process_tree'

    cpus { params.fasttree_max_cpus as int }

    publishDir {
        "${params.outdir}/${params.seq_type}/buildtree/${markerset}/fasttree"
    }, mode: params.publish_mode

    input:
    tuple val(markerset), val(seq_type), path(concat_fa), path(partition)

    output:
    tuple val(markerset), val(seq_type), path("*.fasttree.nosupport.treefile"), emit: treefile
    tuple val(markerset), val(seq_type), path("*.fasttree.support.treefile"),   emit: support
    path "*.fasttree.*.log",                                                    emit: logs, optional: true

    script:
    def prefix = "${concat_fa.baseName}.fasttree"
    // DNA needs -nt; the model flag itself defaults to -gtr (DNA) / -lg (protein).
    def model  = seq_type == 'cds' ? "-nt ${params.fasttree_model_dna}" : "${params.fasttree_model_prot}"
    """
    export OMP_NUM_THREADS=${task.cpus}

    # Fast tree, branch support disabled.
    FastTreeMP ${model} -nosupport ${concat_fa} \\
        > ${prefix}.nosupport.treefile 2> ${prefix}.nosupport.log

    # Tree with SH-like local support from ${params.fasttree_boot} resamples.
    FastTreeMP ${model} -boot ${params.fasttree_boot} ${concat_fa} \\
        > ${prefix}.support.treefile 2> ${prefix}.support.log
    """
}
