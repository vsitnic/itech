# EC2 instance backup 

Simple script to create AMI from EC2 instance and retain last N copies. 
It is very useful for daily/weekly backup.

Usage 

```bash
Usage: ec2_instance_backup.sh [OPTIONS]
  -n, --instance-name     Instance name
  -i, --instance-id       Instance Id
  -r, --retain-copy       Number of copies (default 3)
  -R, --region            Region (default autodetect from local instance)
  -D, --debug             Debug mode
  -H, --help              Print this help
```

AMI name will be formated from "instance-name" argument and current date.
Format : ${instance_name}__`date "+%Y%m%d"`

To keep environment up, we use "noreboot" option.

# EC2 instance self backup

Simple script to get instance properties from AWS and create AMI from EC2 instance and retain last N copies. 
This is "self backup", it works with localhost only.
It is very useful for daily/weekly backup.

Usage 

```bash
Usage: ec2_self_backup.sh [OPTIONS]
  -n, --instance-name     Custom instance name (default get automatically from aws
  -r, --retain-copy       Number of copies (default 3)
  -D, --debug             Debug mode
  -H, --help              Print this help
```


# Requirements
"ec2:DescribeInstances", "ec2:DescribeImages", "ec2:DeregisterImage", "ec2:DeleteSnapshot" granted by aws KEY or server role configured
