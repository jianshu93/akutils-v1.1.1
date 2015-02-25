#!/bin/bash
set -e

# check whether user had supplied -h or --help . If yes display help 
	if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
		echo "
		Usage (order is important!):
		strip_primers.sh <rev/comp_primers> <read1> <read2> <index1> <index2>

		<index2> is optional.

		Resulting files will be output to a subdirectory called fastq-mcf_out.

		This script parallelizes adapter stripping using the fastq-mcf utility from ea-utils.
		For this to work, you must have installed (and in your path) ea-utils and NGSutils.
		This script is intended for Ubuntu 14.04.  I can't help you if you have problems!!

		Importantly, this script trims primers from input fastqs without removing any sequence
		reads which is important if you need to pass an associated index file against them next
		for demultiplexing purposes (eg for QIIME processing of amplicon data).

		Rev/comp primers fasta file should contain somthing like this:
		>515F-1
		TTACCGCGGCTGCTGGCAC
		>515F-2
		TTACCGCGGCGGCTGGCAC
		>806R-1
		ATTAGATACCCTTGTAGTCC
		>806R-2
		ATTAGAAACCCTTGTAGTCC
		>806R-3
		ATTAGATACCCCTGTAGTCC
		"
		exit 0
	fi

## If other than four or five arguments supplied, display usage

	if [[ $# -le 3 ]] || [[ $# -ge 6 ]]; then 
		echo "
		Usage (order is important!):
		strip_primers.sh <rev/comp_primers> <read1> <read2> <index1> <index2>

		<index2> is optional.
   
		Resulting files will be output to a subdirectory called fastq-mcf_out.
		"
		exit 1
	fi 
  
	workdir=$(pwd)
	cd $workdir
	res1=$(date +%s.%N)

## Check for output directory

	if [[ ! -d $workdir/fastq-mcf_out ]]; then

		mkdir -p $workdir/fastq-mcf_out

	else
		echo "		
		Directory fastq-mcf_output exists.
		Attempting to use previously generated files.
		"
	fi

	outdir=$workdir/fastq-mcf_out
	primers=($1)
	read1=($2)
	read2=($3)
	index1=($4)
	index2=($5)
	date0=`date +%Y%m%d_%I%M%p`
	log=($outdir/fastq-mcf_$date0.log)

## Extract filename bases for output naming purposes

		fastq1base=`basename "$read1" | cut -d. -f1`
		fastq2base=`basename "$read2" | cut -d. -f1`
		index1base=`basename "$index1" | cut -d. -f1`
		( cp $index1 $outdir/$index1base.fastq ) &
		if [[ ! -z $index2 ]]; then
		index2base=`basename "$index2" | cut -d. -f1`
		( cp $index2 $outdir/$index2base.fastq ) &
		fi
   
## fastq-mcf command (single process)

	if [[ ! -f $outdir/$fastq1base.mcf.fq ]] && [[ ! -f $outdir/$fastq2base.mcf.fq ]]; then

	echo "
Stripping primers from data with fastq-mcf." >> $log
date "+%a %b %I:%M %p %Z %Y" >> $log
	echo "
---
	
Fastq-mcf command:
          fastq-mcf -0 -t 0.0001 $primers $read1 $read2 -o $outdir/$fastq1base.mcf.fq -o $outdir/$fastq2base.mcf.fq
          " >> $log
   
		echo "
		Stripping primers from your data with
		fastq-mcf.  Building output in directory:
		$outdir
         
		This may take a while..."

		`fastq-mcf -0 -t 0.0001 $primers $read1 $read2 -o $outdir/$fastq1base.mcf.fastq -o $outdir/$fastq2base.mcf.fastq >> $log`
	fi

## Check for and remove empty fastq records

	echo "
Filtering empty fastq records from input files." >> $log
date "+%a %b %I:%M %p %Z %Y" >> $log
	echo "
		Filtering empty fastq records from input files."

		emptycount=`grep -e "^$" $outdir/$fastq1base.mcf.fastq | wc -l`

		if [[ $emptycount != 0 ]]; then

		grep -B 1 -e "^$" $outdir/$fastq1base.mcf.fastq > $outdir/empty.fastq.records
		sed -i '/^\s*$/d' $outdir/empty.fastq.records
		sed -i '/^\+/d' $outdir/empty.fastq.records
		sed -i '/^\--/d' $outdir/empty.fastq.records
		sed -i 's/^\@//' $outdir/empty.fastq.records
		empties=`cat $outdir/empty.fastq.records | wc -l`
	echo "
Found $empties empty fastq records." >> $log
	echo "
		Found $empties empty fastq records."

		( filter_fasta.py -f $outdir/$fastq1base.mcf.fastq -o $outdir/$fastq1base.mcf.noempties.fastq -s $outdir/empty.fastq.records -n ) &
		( filter_fasta.py -f $outdir/$fastq2base.mcf.fastq -o $outdir/$fastq2base.mcf.noempties.fastq -s $outdir/empty.fastq.records -n ) &
		( filter_fasta.py -f $outdir/$index1base.fastq -o $outdir/$index1base.noempties.fastq -s $outdir/empty.fastq.records -n ) &
		if [[ ! -z $index2 ]]; then
		( filter_fasta.py -f $outdir/$index2base.fastq -o $outdir/$index2base.noempties.fastq -s $outdir/empty.fastq.records -n ) &
		fi
		wait
		fi

## Log end of workflow

res2=$(date +%s.%N)
dt=$(echo "$res2 - $res1" | bc)
dd=$(echo "$dt/86400" | bc)
dt2=$(echo "$dt-86400*$dd" | bc)
dh=$(echo "$dt2/3600" | bc)
dt3=$(echo "$dt2-3600*$dh" | bc)
dm=$(echo "$dt3/60" | bc)
ds=$(echo "$dt3-60*$dm" | bc)

runtime=`printf "Total runtime: %d days %02d hours %02d minutes %02.1f seconds\n" $dd $dh $dm $ds`

echo "
		Strip primers workflow steps completed.

		$runtime
"
echo "
---

All workflow steps completed.  Hooray!" >> $log
date "+%a %b %I:%M %p %Z %Y" >> $log
echo "
$runtime 
" >> $log
   