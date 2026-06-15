process PHYKIT_CONCAT {
    tag "${markerset}"
    label "process_short"

    publishDir "${params.outdir}/${params.seq_type}/buildtree", mode: params.publish_mode

    input:
    tuple val(markerset), val(seq_type), path(filter_dir), val(stem)
    val data_type   // 'DNA' or 'PROT' — broadcast value, same for all markersets in a run

    output:
    tuple val(markerset), val(seq_type), path("${stem}.fa"), path("${stem}.partition"), emit: concat

    script:
    """
    ls ${filter_dir}/*.mfa > filenames
    echo "stem = ${stem}"
    phykit create_concat -a filenames -p ${stem}
    sed -i "s/AUTO/${data_type}/" ${stem}.partition
    sed -i -E "s|[[:space:]]+${filter_dir}/||" ${stem}.partition
    """
}
