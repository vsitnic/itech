#!/bin/bash

########################################
#  es_idx_rotate.sh
#  rotate indexes in aliasa
#  Vadim Sitnic
########################################

# Default variables
red='\033[0;31m'
yellow='\033[1;33m'
green='\033[0;32m'
lblue='\033[1;34m'
NC='\033[0m'

es_host="http://localhost:9200"
tmp_path="/tmp/es_utils"

args_count=0

# Defning helper function
print_usage() {
    echo
    echo "Usage: $(basename $0) [OPTIONS]"
    echo "  -h, --es-host           ES Host"
    echo "  -i, --index             ES index"
    echo "  -r, --retain-days       Retain days"
    echo "  -b, --s3-path           s3 path for backup"
    echo "  -t, --tmp-path          local path for temporary exports"
    echo "  -N, --no-color          No color output"
    echo "  -D, --debug             Debug mode"
    echo "  -H, --help              Print this help"
    echo
    echo "Default variables:"
    echo "  es_host: ${es_host}"
    echo
    echo "Example:"
    echo "  $(basename $0) -h ${es_host} -i log90days -r 90 -b s3://backup_bucket/my_index"
    echo
    exit 1
}

debug() {
    message=$1
    if [ -n "$DEBUG" ]; then
         echo -e $message
    fi
}

# Translating argument to --gnu-long-options
for arg; do
    delim=""
    case "$arg" in
        --es-host)                    args="${args}-h " ;;
        --index)                      args="${args}-i " ;;
        --retain-days)                args="${args}-r " ;;
        --s3-path)                    args="${args}-b " ;;
        --tmp-path)                   args="${args}-t " ;;
        --no-color)                   args="${args}-N " ;;
        --debug)                      args="${args}-D " ;;
        --help)                       args="${args}-H " ;;
        *)                      [[ "${arg:0:1}" == "-" ]] || delim="\""
                                args="${args}${delim}${arg}${delim} ";;
    esac
done
eval set -- "$args"

# Parsing arguments
while getopts "h:i:r:b:t:NDH" Option; do
    case $Option in
        h) es_host=$OPTARG ;;
        i) index=$OPTARG; ((args_count++)) ;;
        r) retain_days=$OPTARG; ((args_count++)) ;;
        b) s3_path=$OPTARG; ((args_count++)) ;;
        t) tmp_path=$OPTARG ;;
        N) red='' ;
           yellow='' ;
           green='' ;
           lblue='' ;
           NC='';;
        D) DEBUG="debug" ;;
        *) print_usage; check_result 1 "bad args" ;;
    esac
done

#check args number
if [ "${args_count}" -lt "3" ]; then
     print_usage
fi

# Functions
# place all function here
#-----------------------------------------------#
check_pid_file() {
    if [ -f ${PIDFILE} ]; then
         echo -e "${lblue}INFO:${NC} Rotate process for index ${green}${es_host}/${index}${NC} already running."
         exit 1
    fi
}
#-----------------------------------------------#
create_pid_file() {
    echo ${BASHPID} > ${PIDFILE}
}
#-----------------------------------------------#
rm_pid_file() {
    rm -rf ${PIDFILE}
}
#-----------------------------------------------#
create_empty_index() {
     local index=$1
     local mapping=${2}
#     debug "${lblue}INFO:${NC} Create empty index : curl -s -XPUT ${es_host}'/'${index}"
#     result=$(curl -s -XPUT ${es_host}'/'${index})
     debug "${lblue}INFO:${NC} Create empty index : elasticdump --input=${mapping} --output=${es_host}/${index} --type=mapping"
     result=$(elasticdump --input=${mapping} --output=${es_host}/${index} --type=mapping)
}
#-----------------------------------------------#
delete_index() {
    local index=$1
    debug "${lblue}INFO:${NC} Remove index : curl -XDELETE '${es_host}/${index}'"
    result=$(curl -s  -XDELETE ${es_host}'/'$index )
}
#-----------------------------------------------#
set_alias_idx() {
    local index=$1
    local alias=$2
    debug "${lblue}INFO:${NC} Set alias : curl -s -k -XPOST ${es_host}'/_aliases' -d '{\"actions\":[{\"add\":{\"alias\":\"'${alias}'\",\"index\":\"'${index}'\"}}]}'"
    result=$(curl -s -k -XPOST ${es_host}'/_aliases' -d '{"actions":[{"add":{"alias":"'${alias}'","index":"'${index}'"}}]}' )
}
#-----------------------------------------------#
get_indexes_from_alias() {
    local alias=$1
    debug "${lblue}INFO:${NC} Get indexes from alias : curl -s -XGET ${es_host}'/_alias/'${alias} "
    result=$(curl -s -XGET ${es_host}'/_alias/'${alias} | sed 's|\[||g;s|]||g;s|"||g;s|{||g;s|}||g;s|,||g;s|:|\n|g' | grep "${index}-" | grep -v today | sort )
}
#-----------------------------------------------#
remove_index_from_alias() {
    local index=$1
    local alias=$2
    debug "${lblue}INFO:${NC} Remove alias : curl -s -k -XPOST '${es_host}/_aliases' -d '{"actions":[{"remove":{"alias":"${alias}","index":"${index}"}}]}'"
    result=$(curl -s -k -XPOST ''${es_host}'/_aliases' -d '{"actions":[{"remove":{"alias":"'${alias}'","index":"'${index}'"}}]}' )
}
#-----------------------------------------------#
dump_mapping() {
    local index=$1
    local index_date=$2
    mkdir -p ${tmp_path}/${index_date} > /dev/null
    debug "${lblue}INFO:${NC} Create mapping file : elasticdump --input=${es_host}/${index} --output=${tmp_path}/${index_date}/${index}_mapping.json --type=mapping)"
    result=$(elasticdump --input=${es_host}/${index} --output=${tmp_path}/${index_date}/${index}_mapping.json --type=mapping)
}
#-----------------------------------------------#
get_index_creation_date() {
    local index=$1
    index_date=$(date -d @$(expr $(curl -s -XGET ${es_host}'/'${index}'/_settings' | cut -d '"' -f 10) / 1000) "+%Y/%m/%d")
    debug "${lblue}INFO:${NC} Index date : ${index_date}"
}
#-----------------------------------------------#
dump_index() {
    local index=$1
    local index_date=$2
    get_index_creation_date ${index}
    mkdir -p ${tmp_path}'/'${index_date} > /dev/null
    debug "${lblue}INFO:${NC} Dump data : elasticdump --input=${es_host}'/'${index} --output=${tmp_path}'/'${index_date}'/'${index}'_data.json' --type=data"
    result=$(elasticdump --input=${es_host}'/'${index} --output=${tmp_path}'/'${index_date}'/'${index}'_data.json' --type=data)
}
#-----------------------------------------------#
move_to_s3() {
    aws s3 sync ${tmp_path}'/'${index_date}'/' ${s3_path}'/'${index_date}'/' >/dev/null
    rm -r ${tmp_path}'/'${index_date}
}
#-----------------------------------------------#
get_last_index() {
    local indexes_list=$1
    last_index=$(echo ${indexes_list} | sed 's| |\n|g' | grep . | sort | tail -n 1)
}
#-----------------------------------------------#

# MAIN
# Script body. Please keep "MAIN" as body tag

# get regular host name for PID file
es_dns=$(echo ${es_host} | sed 's|http://||;s|https://||;s|:| |;s|/| |' | cut -d ' ' -f 1)
debug "${lblue}INFO:${NC} es_dns=${yellow}${es_dns}${NC}"
mkdir -p ${tmp_path} > /dev/null

# create and create pid file
PIDFILE='/tmp/es-rotate-'${es_dns}'-'${index}'.pid'
check_pid_file
create_pid_file

today=$(date +%Y-%m-%d)
debug "========== rotate index ${today} ======================="
get_indexes_from_alias "${index}-today"
candidates_to_archive=${result}
debug "${lblue}INFO:${NC} Candidates to archive : ${candidates_to_archive}"

get_last_index "${candidates_to_archive}"
debug "${lblue}INFO:${NC} Last index to archive : ${last_index}"
dump_mapping ${last_index} "mapping"

get_indexes_from_alias "${index}"
debug "${lblue}INFO:${NC} Candidates to delete L1 : ${result}"
candidates_to_delete=$(echo -e "${result}" | sed 's| |\n|g' | sort -r | tail -n +${retain_days} | sort)

create_empty_index "${index}-${today}" "${tmp_path}/mapping/${last_index}_mapping.json"
#create_empty_index "${index}-${today}"
set_alias_idx "${index}-${today}" "${index}-today"
set_alias_idx "${index}-${today}" "${index}"

for previous_index in ${candidates_to_archive}; do
    remove_index_from_alias ${previous_index} "${index}-today"
    get_index_creation_date ${previous_index}
    dump_mapping ${previous_index} ${index_date}
    dump_index ${previous_index} ${index_date}
    move_to_s3
done

debug "${lblue}INFO:${NC} Candidates to delete : ${candidates_to_delete}"
for candidat_to_delete in ${candidates_to_delete}; do
   delete_index ${candidat_to_delete}
done

rm_pid_file
exit 0

