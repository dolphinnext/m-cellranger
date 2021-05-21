$HOSTNAME = ""
params.outdir = 'results'  

//* params.genome_build =  ""  //* @dropdown @options:"human_hg19_GRCh37_87, human_hg38_gencode_v28, mouse_mm10_GRCm38_93, zebrafish_GRCz11plus_ensembl, zebrafish_GRCz11refSeqUcsc, zebrafish_GRCz11_v4.3.2, custom"

_species = ""
_build = ""
_share = ""
_shareGen= ""
//* autofill
if (params.genome_build == "human_hg19_GRCh37_87"){
    _species = "human"
    _build = "hg19"
} else if (params.genome_build == "human_hg38_gencode_v28"){
    _species = "human"
    _build = "hg38_gencode_v28"
} else if (params.genome_build == "mouse_mm10_GRCm38_93"){
    _species = "mouse"
    _build = "mm10"
} else if (params.genome_build == "zebrafish_GRCz11plus_ensembl"){
    _species = "zebrafish"
    _build = "GRCz11"
} else if (params.genome_build == "zebrafish_GRCz11refSeqUcsc"){
    _species = "zebrafish"
    _build = "GRCz11refSeqUcsc"
} else if (params.genome_build == "zebrafish_GRCz11_v4.3.2"){
    _species = "zebrafish"
    _build = "GRCz11_v4.3.2"
}


params.DOWNDIR = (params.DOWNDIR) ? params.DOWNDIR : ""
if ($HOSTNAME == "default"){
    _shareGen = "${params.DOWNDIR}/cellranger"
    $SINGULARITY_IMAGE = "https://galaxyweb.umassmed.edu/pub/dolphinnext_singularity/UMMS-Biocore-singularity-cellranger-v3.simg"
    $MEMORY = 32
}



//* platform
if ($HOSTNAME == "ghpcc06.umassrc.org"){
    _shareGen = "/share/data/umw_biocore/genome_data/cellranger"
    $SINGULARITY_IMAGE = "/project/umw_biocore/singularity/UMMS-Biocore-singularity-cellranger-v3.simg"
    $SINGULARITY_OPTIONS = "--bind /project --bind /share --bind /nl"
    $TIME = 240
    $CPU  = 1
    $MEMORY = 30
    $QUEUE = "short"
}
//* platform
if (params.genome_build && $HOSTNAME){
    params.transcriptome ="${_shareGen}/${_species}/${_build}/${_build}"
    params.cellranger_path = "cellranger"
}
if ($HOSTNAME){
    params.cellranger_path = "cellranger"
}

//* autofill

if (!params.reads){params.reads = ""} 
if (!params.mate){params.mate = ""} 

Channel
	.fromFilePairs( params.reads , size: params.mate == "single" ? 1 : params.mate == "pair" ? 2 : params.mate == "triple" ? 3 : params.mate == "quadruple" ? 4 : -1 )
	.ifEmpty { error "Cannot find any reads matching: ${params.reads}" }
	.into{g_1_reads_g_5;g_1_reads_g_9}

Channel.value(params.mate).into{g_2_mate_g_5;g_2_mate_g_9}

g_1_reads_g_5= g_1_reads_g_5.ifEmpty([""]) 

//* params.cellranger_path =  ""  //* @input
//* params.run_Cell_Ranger_Count =  "yes"  //* @dropdown @options:"yes","no" @show_settings:"Cell_Ranger_Count"
cell_ranger_count_parameters = params.Count.cell_ranger_count_parameters
expected_cells = params.Count.expected_cells
//* params.transcriptome =  ""  //*  @input 
chemistry = params.Count.chemistry

def getLastDirName(row){
   firstSec = row.toString().substring(0,row.toString().lastIndexOf('/'))
   secondSec = firstSec.substring(firstSec.lastIndexOf('/')+1, firstSec.length())
return secondSec
}

//* autofill
if ($HOSTNAME == "default"){
    $CPU  = 3
    $MEMORY = 32
}
//* platform
if ($HOSTNAME == "ghpcc06.umassrc.org"){
    $TIME = 8000
    $CPU  = 6
    $MEMORY = 32
    $QUEUE = "long"
} 
//* platform
//* autofill

process Count {

publishDir params.outdir, overwrite: true, mode: 'copy',
	saveAs: {filename ->
	if (filename =~ /${name}_outs$/) "cellranger_count/$filename"
	else if (filename =~ /${name}_outs\/${name}_web_summary.html$/) "count_web_summary/$filename"
}

input:
 set val(name), file(reads) from g_1_reads_g_5
 val mate from g_2_mate_g_5

output:
 file "${name}_outs"  into g_5_outputDir_g_6
 file "${name}_outs/${name}_web_summary.html"  into g_5_outputHTML

when:
params.run_Cell_Ranger_Count == "yes"

script:
sample = name
nameAll = reads.toString()
nameArray = nameAll.split(' ')
if (mate == "pair"){
    read1 = nameArray[0]
    read2 = nameArray[1]
    if (nameAll.contains('.gz')) {
        runGzip = ''
    } else {
        read1 = read1 + ".gz"
        read2 = read2 + ".gz"
        runGzip = "ls * | xargs -i echo gzip -f {} | sh"
    }
    mvReads = "mv " +read1 +" reads/"+ name + "_S1_L001_R1_001.fastq.gz && mv " +read2 +" reads/"+ name + "_S1_L001_R2_001.fastq.gz"  
} else {
    read1 = nameArray[0]
    if (nameAll.contains('.gz')) {
        runGzip = ''
    } else {
        read1 = read1 + ".gz"
        runGzip = "ls * | xargs -i echo gzip -f {} | sh"
    }
    mvReads = "mv " +read1 +" reads/"+ name + "_S1_L001_R1_001.fastq.gz"
}

"""
$runGzip
mkdir reads
$mvReads

## cell ranger expect this pattern ${name}_S1_L00[Lane Number]_[Read Type]_001.fastq.gz
${params.cellranger_path} count --id=$name \
                   --transcriptome=${params.transcriptome} \
                   --fastqs=reads \
                   --sample=$sample \
                   --expect-cells=$expected_cells \
                   --chemistry=$chemistry $cell_ranger_count_parameters
                   

mv ${name}/outs ${name}_outs
rm -rf ${name}
cp ${name}_outs/web_summary.html ${name}_outs/${name}_web_summary.html
"""
}

aggregate_run_id = params.Aggr.aggregate_run_id
normalizeDepth = params.Aggr.normalizeDepth
//* params.run_Aggregate_Libraries =  "no"  //* @dropdown @options:"yes","no" @show_settings:"Cell_Ranger_Aggr"
//* params.cellranger_path =  ""  //* @input
//* autofill
if ($HOSTNAME == "default"){
    $CPU  = 1
    $MEMORY = 32
}
//* platform
if ($HOSTNAME == "ghpcc06.umassrc.org"){
    $TIME = 1500
    $CPU  = 1
    $MEMORY = 32
    $QUEUE = "long"
} 
//* platform
//* autofill
if (!(params.run_Aggregate_Libraries == "yes")){
g_5_outputDir_g_6.into{g_6_outputDir}
g_6_outputHTML = Channel.empty()
} else {


process Aggr {

publishDir params.outdir, overwrite: true, mode: 'copy',
	saveAs: {filename ->
	if (filename =~ /${aggregate_run_id}\/outs$/) "cellranger_aggr/$filename"
	else if (filename =~ /${aggregate_run_id}\/outs\/web_summary.html$/) "aggr_web_summary/$filename"
}

input:
 file "*" from g_5_outputDir_g_6.collect()

output:
 file "${aggregate_run_id}/outs"  into g_6_outputDir
 file "${aggregate_run_id}/outs/web_summary.html"  into g_6_outputHTML

when:
params.run_Aggregate_Libraries == "yes"

script:
aggregate_run_id = aggregate_run_id.trim().replaceAll(" ", "_")

"""
for i in * ; do
   echo "\$i,\$(ls -d \$PWD/\$i/molecule_info.h5)" >> all_libraries.csv
done
echo -e "library_id,molecule_h5\n\$(cat all_libraries.csv)" > all_libraries.csv
${params.cellranger_path} aggr --id=${aggregate_run_id} \
                  --csv=all_libraries.csv \
                  --normalize=${normalizeDepth}
"""
}
}


//* params.run_FastQC =  "no"  //* @dropdown @options:"yes","no" @description:"FastQC provides quality control checks on raw sequence data."



process FastQC {

publishDir params.outdir, overwrite: true, mode: 'copy',
	saveAs: {filename ->
	if (filename =~ /.*.(html|zip)$/) "fastqc/$filename"
}

input:
 val mate from g_2_mate_g_9
 set val(name), file(reads) from g_1_reads_g_9

output:
 file '*.{html,zip}'  into g_9_FastQCout_g_12

errorStrategy 'retry'
maxRetries 3

when:
(params.run_FastQC && (params.run_FastQC == "yes"))

script:
nameAll = reads.toString()
if (nameAll.contains('.gz')) {
    file =  nameAll - '.gz' - '.gz'
    runGzip = "ls *.gz | xargs -i echo gzip -df {} | sh"
} else {
    file =  nameAll 
    runGzip = ''
}
"""
${runGzip}
fastqc ${file} 
"""
}

//* autofill
//* platform
if ($HOSTNAME == "ghpcc06.umassrc.org"){
    $TIME = 240
    $CPU  = 1
    $MEMORY = 10
    $QUEUE = "short"
}
//* platform
//* autofill

process MultiQC {

publishDir params.outdir, overwrite: true, mode: 'copy',
	saveAs: {filename ->
	if (filename =~ /multiqc_report.html$/) "multiQC/$filename"
}

input:
 file "fastqc/*" from g_9_FastQCout_g_12.flatten().toList()

output:
 file "multiqc_report.html" optional true  into g_12_outputHTML

errorStrategy 'retry'
maxRetries 2

script:
"""
multiqc -e general_stats -d -dd 2 .
"""
}


workflow.onComplete {
println "##Pipeline execution summary##"
println "---------------------------"
println "##Completed at: $workflow.complete"
println "##Duration: ${workflow.duration}"
println "##Success: ${workflow.success ? 'OK' : 'failed' }"
println "##Exit status: ${workflow.exitStatus}"
}
