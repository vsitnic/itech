
# Default variables
red='\033[0;31m'
yellow='\033[1;33m'
green='\033[0;32m'
lblue='\033[1;34m'
NC='\033[0m'

args_count=0

# Functions
# place all function here
#-----------------------------------------------#
debug() {
    message=$1
    if [ -n "$DEBUG" ]; then
         echo -e $message
    fi
}
#-----------------------------------------------#
check_pid_file() {
    if [ -f ${PIDFILE} ]; then
         echo -e "${lblue}INFO:${NC} Rotate process for index ${green}${es_host}/${index}${NC} already running. Please check PID ${PIDFILE}"
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
date2date() {
    local date=$1
    date -d "${date}" "+%Y-%m-%d"
}
#-----------------------------------------------#
date2path() {
    local date=$1
    date -d "${date}" "+%Y/%m/%d"
}
#-----------------------------------------------#
convert_path() {
    local path=$1
    echo "${path}" | sed 's|\/$||'
}
#-----------------------------------------------#
host2dns() {
    local host=$1
    dns=$(echo $host | sed 's|http://||;s|https://||;s|:| |' | cut -d ' ' -f 1)
    echo ${dns}
}
#-----------------------------------------------#
check_path_type() {
    local path=$1
    if [[ "$path" =~ ^s3:// ]]; then
        path_type="s3"
    elif [[ "$path" =~ ^/ ]]; then
        path_type="local"
    else 
        echo "Wrong backup path. Please use full local or S3 path"
        exit 1
    fi 
}
#-----------------------------------------------#
check_path_exists() {
    local path=$1
    local path_type=$2
    case "${path_type}" in
        s3)       result=$(aws s3 ls ${path} | wc -l) ;;
        local)    result=$(ls ${path} 2>/dev/null | wc -l) ;;
    esac
    if [ "${result}" -eq "0" ]; then
        echo "ERROR: ${path} doesn't exist"
        exit 1
    fi
}
#-----------------------------------------------#
check_index_type() {
    local es_host=$1
    local index=$2
    debug "${lblue}INFO:${NC} Get index type curl -s -XGET ${es_host}'/_cat/aliases/'${index}"
    result=$(curl -s -XGET ${es_host}'/_cat/aliases/'${index})
    if [ "${result}" == "" ]; then
        index_type="index"
    else 
        index_type="alias"
    fi
}
#-----------------------------------------------#
set_alias_idx() {
    local index=$1
    local alias=$2
    debug "${lblue}INFO:${NC} Set alias : curl -s -k -XPOST ${es_host}'/_aliases' -d '{\"actions\":[{\"add\":{\"alias\":\"'${alias}'\",\"index\":\"'${index}'\"}}]}'"
    result=$(curl -s -k -XPOST ${es_host}'/_aliases' -d '{"actions":[{"add":{"alias":"'${alias}'","index":"'${index}'"}}]}' )
}
#-----------------------------------------------#
