#!/bin/bash

########################################
#  es_restore_index.sh
#  restore index and add to alias
#  Vadim Sitnic
########################################

# Default variables

# make separate folder for restore
tmp_path="/tmp/es_utils/restore/"
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
    echo "  -d, --date              ES index date (mandatory)"
    echo "  -P, --path              backup path, S3 or local. Check notes* (mandatory)"
    echo "  -m, --mapping           mapping file"
    echo "  -t, --tmp-path          local path for temporary exports"
    echo "  -N, --no-color          No color output"
    echo "  -D, --debug             Debug mode"
    echo "  -H, --help              Print this help"
    echo
    echo "Examples:"
    echo "  $(basename $0) -h ${es_host} -i log90days -d \"12 Mar 2015\" -b s3://backup_bucket/"
    echo "  $(basename $0) -h ${es_host} -i log90days -d 2015-09-01 -b /data/backup/"
    echo "  $(basename $0) -h ${es_host} -i log90days -d 2015/09/01 -b s3://backup_bucket"
    echo "  $(basename $0) -h ${es_host} -i log90days -d \"month ago\" -b s3://backup_bucket/"
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
        --mapping)                    args="${args}-m " ;;
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
while getopts "h:i:d:P:m:t:NDH" Option; do
    case $Option in
        h) es_host=$OPTARG; ((args_count++)) ;;
        i) index=$OPTARG; ((args_count++)) ;;
        d) restore_date=$OPTARG; ((args_count++)) ;;
        P) backup_path=$OPTARG; ((args_count++)) ;;
        m) mapping=$OPTARG ;;
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
if [ "${args_count}" -lt "4" ]; then
     print_usage
fi

# MAIN

# Basic transformations
es_dns=$(host2dns ${es_host})
index_date=$(date2date "${restore_date}")
path_date=$(date2path "${restore_date}")
backup_path=$(convert_path "${backup_path}")

debug "${lblue}INFO:${NC} ES dns ${es_dns}"

# Check index type, index or alias
check_index_type  ${es_host} ${index}
debug "${lblue}INFO:${NC} Index type ${green}${index_type}${NC}"
if [ ! "${index_type}" == "alias" ]; then
    debug "${red}ERROR:${NC} ${index} must be alias" 
    echo "ERROR: ${index} must be alias"
    exit 1
fi

# Check path type, local or S3
check_path_type ${backup_path}
debug "${lblue}INFO:${NC} Path type ${path_type}"

# Check files exist
check_path_exists ${backup_path}/${es_dns}/${index}/${path_date}/${index}-${index_date}_mapping.json ${path_type}
debug "${lblue}INFO:${NC} mapping file exists"
check_path_exists ${backup_path}/${es_dns}/${index}/${path_date}/${index}-${index_date}_data.json ${path_type}
debug "${lblue}INFO:${NC} data file exists"

# copy backup to local tmp
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

# Restore index
elasticdump --input=${tmp_path}/${index}-${index_date}_mapping.json --output=${es_host}/${index}-${index_date} --type=mapping
elasticdump --input=${tmp_path}/${index}-${index_date}_data.json --output=${es_host}/${index}-${index_date} --type=data

# Set working alias
set_alias_idx ${index}-${index_date} ${index}-archive

# Remove temp files
rm -f ${tmp_path}/${index}-${index_date}_mapping.json ${tmp_path}/${index}-${index_date}_data.json
