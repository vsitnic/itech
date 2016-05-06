#!/bin/bash

###########################################################
#
# ec2-instance backup script.
# instance ID required
# By default it gets instance name from AWS console and create AMI with "noreboot"
# Keep 3 copy by default
#
# Add cron job according to your requirements (daily/weekly/monthly)
#
###########################################################


profile=''
## USES ICX_USER PROFILE IN ~/.aws/config

region=$(curl  -s http://169.254.169.254/latest/dynamic/instance-identity/document | grep region|awk -F\" '{print $4}')
instance_id=''
retain=3
now=$(date "+%Y-%m-%d_%H-%M-%S")


# Defning helper function
print_usage() {
    echo
    echo "Usage: $(basename $0) [OPTIONS]"
    echo "  -i, --instance-id       Instance ID (mandatory)"
    echo "  -n, --instance-name     Custom instance name (default get automatically from aws)"
    echo "  -r, --retain-copy       Number of copies (default ${retain})"
    echo "  -p, --profile           Profile, if special"
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
        --instance-id)                args="${args}-i " ;;
        --instance-name)              args="${args}-n " ;;
        --retain-copy)                args="${args}-r " ;;
        --profile)                    args="${args}-p " ;;
        --debug)                      args="${args}-D " ;;
        --help)                       args="${args}-H " ;;
        *)                      [[ "${arg:0:1}" == "-" ]] || delim="\""
                                args="${args}${delim}${arg}${delim} ";;
    esac
done
eval set -- "$args"

# Parsing arguments
while getopts "i:n:r:p:DH" Option; do
    case $Option in
        i) instance_id=$OPTARG ;;
        n) instance_name=$OPTARG ;;
        r) retain=$OPTARG ;;
        p) profile="--profile $OPTARG" ;;
        D) DEBUG="debug" ;;
        *) print_usage; check_result 1 "bad args" ;;
    esac
done

# MAIN
if [ "${instance_id}" == "" ]; then
    print_usage
fi

#Get instance name
instance_name=$(aws ec2 describe-tags  --region us-west-2 --filters "Name=resource-id,Values=${instance_id}" --output text | awk '{print $5}')

#Get AMIs
debug "INFO: Get AMIs"
amis=$(/usr/bin/aws ec2 describe-images ${profile} --region ${region} --filters "Name=name,Values=${instance_name}__*" --query 'Images[*].{Name:Name,ID:ImageId}')
debug "INFO: ${amis}"

amis=$(echo ${amis} | sed 's|\[||g;s|]||g;s| ||g;s|":|=|g;s|},{"|\n|g;s|{"||g;s|,"|;|g;s|\}||g' | sort |  head -n $(expr 1 - ${retain}))
debug "INFO: to delete : ${amis}"

for candidat in ${amis}; do
    eval ${candidat}
    debug "INFO: Get ${ID} snapshots"
    snaps=$(aws ec2 describe-images ${profile} --region ${region} --image-ids ${ID} --output text --query 'Images[*].BlockDeviceMappings[*].Ebs.SnapshotId')
    debug "INFO: Snapshots ${snaps}"
    debug "INFO: Delete ${ID}"
    res=$(/usr/bin/aws ec2 deregister-image ${profile} --region ${region} --image-id ${ID})
    for snap in ${snaps}; do
        debug "INFO: + Delete snapshot ${snap}"
        res=$(aws ec2 delete-snapshot ${profile} --region ${region} --snapshot-id ${snap} )
    done
done

# Create AMI
debug "INFO: Creating AMI"
ami=$(aws ec2 create-image ${profile} --region ${region} --no-reboot --instance-id ${instance_id} --no-reboot --name ${instance_name}"__"${now})
debug "INFO: ${ami}"
ami=$(echo ${ami} | cut -d '"' -f 4)
debug "INFO: Tag AMI ${instance_name}"
tag=$(aws ec2 create-tags ${profile} --region ${region} --resources ${ami} --tags Key=Name,Value=${instance_name}"__"${now} )
debug "INFO: ${tag}"
exit
