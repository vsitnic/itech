#!/bin/bash

########################################
#  es_backup_index.sh
#  backup single index with mapping
#  Vadim Sitnic
########################################

# Default variables

# make separate folder for restore
tmp_path="/tmp/es_utils/backup/"
mkdir -p ${tmp_path}

es_utils_path=$(dirname $(realpath $0))

# Common func
IMPORTLIBS=(
    es_libs.sh
)

# Checking and importing libraries
for libfile in ${IMPORTLIBS[*]}; do
    if [ -e "${es_utils_path}/${libfile}" ]; then
       source "${es_utils_path}/${libfile}"
    else
       echo "Error: File [${es_utils_path}/${libfile}] doesn't exist!!!"
       exit 1
    fi
done


# Defning helper function
print_usage() {
    echo
    echo "Usage: $(basename $0) [OPTIONS]"
    echo "  -h, --es-host           ES Host (mandatory)"
    echo "  -i, --index             ES index (mandatory)"
    echo "  -d, --date              ES index date, default \"today\" "
    echo "  -P, --path              backup path, S3 or local. Check notes* (mandatory)"
    echo "  -t, --tmp-path          local path for temporary exports"
    echo "  -N, --no-color          No color output"
    echo "  -D, --debug             Debug mode"
    echo "  -H, --help              Print this help"
    echo
    echo "Examples:"
    echo "  $(basename $0) -h ${es_host} -i log90days -b /data/backup/"
    echo "  $(basename $0) -h ${es_host} -i log90days -b s3://backup_bucket"
    echo
    echo "Notes* : "
    echo "  full backup path will be calculated as \"provided_path/es_cluster_dns_name/index_name/YYYY/DD/MM/\" "
    echo
    exit 1
}

# Translating argument to --gnu-long-options
for arg; do
    delim=""
    case "$arg" in
        --es-host)                    args="${args}-h " ;;
        --index)                      args="${args}-i " ;;
        --date)                       args="${args}-d " ;;
        --path)                       args="${args}-P " ;;
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
while getopts "h:i:d:P:t:NDH" Option; do
    case $Option in
        h) es_host=$OPTARG; ((args_count++)) ;;
        i) index=$OPTARG; ((args_count++)) ;;
        d) backup_date=$OPTARG ;;
        P) backup_path=$OPTARG; ((args_count++)) ;;
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

# MAIN

# Basic transformations
es_dns=$(host2dns ${es_host})
index_date=$(date2date "${backup_date}")
path_date=$(date2path "${backup_date}")
backup_path=$(convert_path "${backup_path}")

debug "${lblue}INFO:${NC} ES dns ${es_dns}"

# Check path type, local or S3
check_path_type ${backup_path}
debug "${lblue}INFO:${NC} Path type ${path_type}"

# Create temp loacal backup path 
mkdir -p ${tmp_path}/${es_dns}/${index}/${path_date}

# Backup index
elasticdump --input=${es_host}/${index} --output=${tmp_path}/${es_dns}/${index}/${path_date}/${index}_mapping.json --type=mapping 
elasticdump --input=${es_host}/${index} --output=${tmp_path}/${es_dns}/${index}/${path_date}/${index}_data.json --type=data 

exit 255

# copy local tmp to baclup
case  "${path_type}" in 
    s3)
        aws s3 cp ${backup_path}/${es_dns}/${index}/${path_date}/${index}-${index_date}_mapping.json ${tmp_path}/ >/dev/null ;
        aws s3 cp ${backup_path}/${es_dns}/${index}/${path_date}/${index}-${index_date}_data.json ${tmp_path}/ >/dev/null ;
    ;;
    local)
        cp ${backup_path}/${es_dns}/${index}/${path_date}/${index}-${index_date}_mapping.json ${tmp_path}/ >/dev/null ;
        cp ${backup_path}/${es_dns}/${index}/${path_date}/${index}-${index_date}_data.json ${tmp_path}/ >/dev/null ;
    ;;
esac


# Set working alias
set_alias_idx ${index}-${index_date} ${index}-archive

# Remove temp files
rm -f ${tmp_path}/${index}-${index_date}_mapping.json ${tmp_path}/${index}-${index_date}_data.json
