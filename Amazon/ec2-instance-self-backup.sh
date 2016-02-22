#!/bin/bash
###########################################################
#
# ec2-instance self backup script. 
# No args required 
# By default it gets instance name from AWS console and create AMI with "noreboot" 
# Keep 3 copy by default
#
# Add cron job according to your requirements (daily/weekly/monthly)
#
###########################################################

## USES USER PROFILE IN ~/.aws/config indirect
## Can be replaces by configured server role

region=$(curl  -s http://169.254.169.254/latest/dynamic/instance-identity/document | grep region|awk -F\" '{print $4}')
instance_name=$(curl -s http://169.254.169.254/latest/meta-data/public-keys/ | cut -d '=' -f 2 )
instance_id=$(curl -s http://169.254.169.254/latest/meta-data/instance-id/)
retain=3


# Defning helper function
print_usage() {
    echo
    echo "Usage: $(basename $0) [OPTIONS]"
    echo "  -n, --instance-name     Custom instance name (default get automatically from aws)"
    echo "  -r, --retain-copy       Number of copies (default 3)"
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
        --retain-copy)                args="${args}-r " ;;
        --debug)                      args="${args}-D " ;;
        --help)                       args="${args}-H " ;;
        *)                      [[ "${arg:0:1}" == "-" ]] || delim="\""
                                args="${args}${delim}${arg}${delim} ";;
    esac
done
eval set -- "$args"

# Parsing arguments
while getopts "n:r:DH" Option; do
    case $Option in
        n) instance_name=$OPTARG ; args_count=$(expr ${args_count} + 1 );;
        r) retain=$OPTARG ;;
        D) DEBUG="debug" ;;
        *) print_usage; check_result 1 "bad args" ;;
    esac
done

#Get AMIs
debug "INFO: Get AMIs"
amis=$(/usr/bin/aws ec2 describe-images --filters "Name=name,Values=${instance_name}__*" --query 'Images[*].{Name:Name,ID:ImageId}')
debug "INFO: ${amis}"

amis=$(echo ${amis} | sed 's|\[||g;s|]||g;s| ||g;s|":|=|g;s|},{"|\n|g;s|{"||g;s|,"|;|g;s|\}||g' | sort |  head -n $(expr 1 - ${retain}))
debug "INFO: to delete : ${amis}"

for candidat in ${amis}; do
    eval ${candidat}
    debug "INFO: Get ${ID} snapshots"
    snaps=$(aws ec2 describe-images --region ${region} --image-ids ${ID} --output text --query 'Images[*].BlockDeviceMappings[*].Ebs.SnapshotId')
    debug "INFO: Snapshots ${snaps}"
    debug "INFO: Delete ${ID}"
    res=$(/usr/bin/aws ec2 deregister-image --region ${region} --image-id ${ID})
    for snap in ${snaps}; do
        debug "INFO: + Delete snapshot ${snap}"
        res=$(aws ec2 delete-snapshot --snapshot-id ${snap} --region ${region})
    done
done

# Create AMI
debug "INFO: Creating AMI"
ami=$(aws ec2 create-image --no-reboot --region=${region} --instance-id ${instance_id} --no-reboot --name ${instance_name}__`date "+%Y-%m-%d_%H-%M-%S"`)
debug "INFO: ${ami}"

exit
