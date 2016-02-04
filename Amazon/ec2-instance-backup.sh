#!/bin/bash

########################################
#  backup ec2 instance
#  with retain limited number of backups
#  vsitnic@gmail.com 
########################################


region="us-west-2"
retain=3

args_count=0

# Defning helper function
print_usage() {
    echo
    echo "Usage: $(basename $0) [OPTIONS]"
    echo "  -n, --instance-name     Instance name"
    echo "  -i, --instance-id       Instance Id"
    echo "  -r, --retain-copy       Number of copies (default 3)"
    echo "  -R, --region            Region (default us-west-2)"
    echo "  -D, --debug             Debug mode"
    echo "  -H, --help              Print this help"
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
        --instance-name)              args="${args}-n " ;;
        --instance-id)                args="${args}-i " ;;
        --retain-copy)                args="${args}-r " ;;
        --region)                     args="${args}-R " ;;
        --debug)                      args="${args}-D " ;;
        --help)                       args="${args}-H " ;;
        *)                      [[ "${arg:0:1}" == "-" ]] || delim="\""
                                args="${args}${delim}${arg}${delim} ";;
    esac
done
eval set -- "$args"

# Parsing arguments
while getopts "n:i:r:R:DH" Option; do
    case $Option in
        n) instance_name=$OPTARG ; args_count=$(expr ${args_count} + 1 );;
        i) instance_id=$OPTARG ; args_count=$(expr ${args_count} + 1 );;
        r) retain=$OPTARG ;;
        R) region=$OPTARG ;;
        D) DEBUG="debug" ;;
        *) print_usage; check_result 1 "bad args" ;;
    esac
done

if [ "${args_count}" -lt "2" ]; then
     print_usage
fi

#Get AMIs
debug "INFO: Get AMIs"
amis=$(/usr/bin/aws ec2 describe-images --filters "Name=name,Values=${instance_name}*" --query 'Images[*].{Name:Name,ID:ImageId}')
debug "INFO: ${amis}"

# AMIs to delete
amis=$(echo ${amis} | sort | sed 's|\[||g;s|]||g;s| ||g;s|":|=|g;s|},{"|\n|g;s|{"||g;s|,"|;|g;s|\}||g' | head -n $(expr 1 - ${retain}))
debug "INFO: to delete : ${amis}"

# Delete old backups
for candidat in ${amis}; do
    eval ${candidat}
    debug "INFO: Delte ${ID}"
    res=$(/usr/bin/aws ec2 deregister-image --image-id ${ID})
    debug "INFO ${res}"
done

# Create AMI
debug "INFO: Creating AMI"
ami=$(/usr/bin/aws ec2 create-image --region ${region} --instance-id ${instance_id} --no-reboot --name ${instance_name}-`date "+%Y%m%d"`)
debug "INFO: ${ami}"

exit
