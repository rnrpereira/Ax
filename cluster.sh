#!/bin/bash

# cd to folder containing cluster.sh and then execute:
#     ./cluster.sh  <R|US> full_path_to_folder  [start_sec]  [stop_sec]
# for example
#     ./cluster.sh  US /groups/egnor/egnorlab/for_ben/sys_test_07052012a/demux/
# use R for rejection calls, and US for ultrasonic vocalizations

# FS, NW, K, PVAL, and NFFT specify the parameters to each call of mtbp().
# if any are a scalar the same value is used for each call.

if [ $# -ne 2 ]
then
  echo not enough arguments
  exit
fi

if [ $1 == 'US' ] ; then
  FS=450450;  # Hz
  #NW=15
  #K=29
  NW=22
  K=43
  PVAL=0.01
  NFFT=(0.001 0.0005 0.00025)  # sec (rounds up to next power of 2 tics)
elif [ $1 == 'R' ]; then
  FS=450450;  # Hz
  NW=18
  K=24
  PVAL=0.01
  NFFT=(0.009 0.0045 0.0022)  # sec (rounds up to next power of 2 tics)
else
  echo first argument must either be R or US
  exit
fi

# get maximum length of params
tmp=(${#FS[@]} ${#NW[@]} ${#K[@]} ${#PVAL[@]} ${#NFFT[@]})
tmp=$(echo ${tmp[@]} | awk -v RS=" " '1' | sort -nr | head -1)

# expand scalars to vector of above max len
if [ ${#FS[@]} -lt $tmp ] ; then
  for i in $(seq 1 $(($tmp - 1)))
  do FS[i]=${FS[0]}; done
fi

if [ ${#NW[@]} -lt $tmp ] ; then
  for i in $(seq 1 $(($tmp - 1)))
  do NW[i]=${NW[0]}; done
fi

if [ ${#K[@]} -lt $tmp ] ; then
  for i in $(seq 1 $(($tmp - 1)))
  do K[i]=${K[0]}; done
fi

if [ ${#PVAL[@]} -lt $tmp ] ; then
  for i in $(seq 1 $(($tmp - 1)))
  do PVAL[i]=${PVAL[0]}; done
fi

if [ ${#NFFT[@]} -lt $tmp ] ; then
  for i in $(seq 1 $(($tmp - 1)))
  do NFFT[i]=${NFFT[0]}; done
fi

#echo ${FS[@]}
#echo ${NW[@]}
#echo ${K[@]}
#echo ${PVAL[@]}
#echo ${NFFT[@]}

# launch one instance of mtbp() per set of params
for i in $(ls -1 $2/*.ch* | sed s/.ch[0-9]// | uniq)
do
#  echo $i
  job_name=$(basename $i)
  for j in $(seq 0 $((${#NFFT[@]} - 1)))
  do
#    echo $j
    qsub -N "$job_name-$j" -pe batch 8 -b y -j y -cwd -o "$2/$job_name-$j.log" -V ./cluster2.sh "\"$i\"" "\"${FS[j]}\"" "\"${NFFT[j]}\"" "\"${NW[j]}\"" "\"${K[j]}\"" "\"${PVAL[j]}\"" "\"$3\"" "\"$4\""
  done
done
