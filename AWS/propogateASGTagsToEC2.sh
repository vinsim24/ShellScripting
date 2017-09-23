#!/bin/bash

if [ $# -lt 2 ]; then
        echo "Usage: $0  autoScalingGroupName region"
        echo "e.g: $0 TestASg vir"
        exit
fi


autoScalingGroupName=$1
region=$2

if [ "$region" == "vir" ]; then
	awsRegion="us-east-1"
elif [ "$region" == "ore" ]; then
	awsRegion="us-west-2"
else
	awsRegion="us-east-1"
fi

echo aws autoscaling describe-auto-scaling-groups --query "AutoScalingGroups[?contains(AutoScalingGroupName,\`$autoScalingGroupName\`) == \`true\`].{AutoScalingGroupName:AutoScalingGroupName}" --output text --region "$awsRegion"

asgNames=$(aws autoscaling describe-auto-scaling-groups --query "AutoScalingGroups[?contains(AutoScalingGroupName,\`$autoScalingGroupName\`) == \`true\`].{AutoScalingGroupName:AutoScalingGroupName}" --output text --region "$awsRegion")

asgNamesArr=( $asgNames )

for asgName in ${asgNamesArr[@]};
do
	echo "ASG Name::$asgName"

	echo aws autoscaling describe-tags --filters "Name=auto-scaling-group,Values=$asgName" --query "Tags[].{Key:Key,Value:Value}" --region "$awsRegion"
	asgTags=$(aws autoscaling describe-tags --filters "Name=auto-scaling-group,Values=$asgName" --query "Tags[].{Key:Key,Value:Value}" --region "$awsRegion")
	finalASGTags="{\"Tags\":$asgTags}"

	echo "ASG Tags::$finalASGTags"
	echo $finalASGTags > tmpFile.json

	echo aws autoscaling describe-auto-scaling-instances --query "AutoScalingInstances[?contains(AutoScalingGroupName,\`$asgName\`) == \`true\`].{InstanceId:InstanceId}" --output text --region "$awsRegion"

	asgInstanceIds=$(aws autoscaling describe-auto-scaling-instances --query "AutoScalingInstances[?contains(AutoScalingGroupName,\`$asgName\`) == \`true\`].{InstanceId:InstanceId}" --output text --region "$awsRegion")
	
	asgInstanceIdsArr=( $asgInstanceIds )
	
	for asgInstanceId in ${asgInstanceIdsArr[@]};
	do
		echo aws ec2 delete-tags --resources "$asgInstanceId" --region "$awsRegion"
                aws ec2 delete-tags --resources "$asgInstanceId" --region "$awsRegion"

		echo aws ec2 create-tags --resources "$asgInstanceId" --cli-input-json "file://tmpFile.json" --region "$awsRegion"
                aws ec2 create-tags --resources "$asgInstanceId" --cli-input-json "file://tmpFile.json" --region "$awsRegion"
	done

	rm tmpFile.json

done
