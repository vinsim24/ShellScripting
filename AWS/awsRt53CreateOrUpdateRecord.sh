#!/bin/bash
set +x

SWD=$(dirname $0)

AWS_REGION=$1
AWS_RT53_ZONEID=$2
AWS_RT53_RECORD_NAME=$3
AWS_RT53_RECORD_VALUE=$4
AWS_RT53_RECORD_TYPE=$5
AWS_RT53_RECORD_ACTION=$6

if [ $# -lt 5 ]; then
        echo "Usage: $0 <aws_region> <aws_rt53_zoneid> <aws_rt53_record_name> <aws_rt53_record_value> <aws_rt53_record_type> [aws_rt53_record_action]"
        echo "E.g.,: $0 us-east-1 XXXXXXX _amazonses.example.com xxxxxxxxxxx TXT [destroy]"
        exit 1
fi

AWS=/usr/bin/aws
changeResourceRecordSetsFile="/tmp/$(basename $0).$$.json"

#echo $AWS route53 list-resource-record-sets --hosted-zone-id "$AWS_RT53_ZONEID" --query "ResourceRecordSets[?Type == \`$AWS_RT53_RECORD_TYPE\`]|[?contains(Name, \`$AWS_RT53_RECORD_NAME\`) == \`true\`].{Value:ResourceRecords[*].Value}" --output text

CUR_RECORD_VALUES=$($AWS route53 list-resource-record-sets --hosted-zone-id "$AWS_RT53_ZONEID" --query "ResourceRecordSets[?Type == \`$AWS_RT53_RECORD_TYPE\`]|[?contains(Name, \`$AWS_RT53_RECORD_NAME\`) == \`true\`].{Value:ResourceRecords[*].Value}" --output text | awk '{ print $2}')

if [ -z "$AWS_RT53_RECORD_ACTION" ];then
    AWS_RT53_RECORD_ACTION="UPSERT"
    if [ -z "$CUR_RECORD_VALUES" ];then
            FINAL_AWS_RT53_RECORD_VALUE="{ \"Value\": \"\\\"$AWS_RT53_RECORD_VALUE\\\"\" }"
    else
        CUR_RECORD_VALUES_ARR=( $CUR_RECORD_VALUES )
        for CUR_RECORD_VALUE in ${CUR_RECORD_VALUES_ARR[@]};
        do
            #echo "$CUR_RECORD_VALUE"
            if [[ $CUR_RECORD_VALUE =~  "$AWS_RT53_RECORD_VALUE" ]];then
                exit
            fi
            CUR_RECORD_VALUE=$(echo "$CUR_RECORD_VALUE" | sed 's/"/\\"/g')
            FINAL_AWS_RT53_RECORD_VALUE+="{ \"Value\": \"$CUR_RECORD_VALUE\" },"
        done
        FINAL_AWS_RT53_RECORD_VALUE+="{ \"Value\": \"\\\"$AWS_RT53_RECORD_VALUE\\\"\" }"
    fi
elif [ "$AWS_RT53_RECORD_ACTION" == "destroy" ];then
    if [ -z "$CUR_RECORD_VALUES" ];then
        exit
    fi

    CUR_RECORD_VALUES_ARR=( $CUR_RECORD_VALUES )
    CUR_RECORD_VALUES_ARR_LENGTH=$(echo "${#CUR_RECORD_VALUES_ARR[@]}")

    if [ "$CUR_RECORD_VALUES_ARR_LENGTH" -eq "1" ];then
        CUR_RECORD_VALUE=${CUR_RECORD_VALUES_ARR[0]}
        if [[ ${CUR_RECORD_VALUE} =~  "$AWS_RT53_RECORD_VALUE" ]];then
            AWS_RT53_RECORD_ACTION="DELETE"
            CUR_RECORD_VALUE=$(echo "$CUR_RECORD_VALUE" | sed 's/"/\\"/g')
            FINAL_AWS_RT53_RECORD_VALUE="{ \"Value\": \"$CUR_RECORD_VALUE\" }"
        else
            exit
        fi
    else
        for CUR_RECORD_VALUE in ${CUR_RECORD_VALUES_ARR[@]};
        do
            if [[ $CUR_RECORD_VALUE =~  "$AWS_RT53_RECORD_VALUE" ]];then
                continue
            else
                CUR_RECORD_VALUE=$(echo "$CUR_RECORD_VALUE" | sed 's/"/\\"/g')
                FINAL_AWS_RT53_RECORD_VALUE+="{ \"Value\": \"$CUR_RECORD_VALUE\" },"
            fi
        done
        FINAL_AWS_RT53_RECORD_VALUE=$(echo "${FINAL_AWS_RT53_RECORD_VALUE::-1}")
        AWS_RT53_RECORD_ACTION="UPSERT"

    fi
fi

cat <<_EOT_>$changeResourceRecordSetsFile
    {
        "Changes": [
            {
                "Action": "$AWS_RT53_RECORD_ACTION",
                "ResourceRecordSet": {
                    "Name": "$AWS_RT53_RECORD_NAME",
                    "Type": "$AWS_RT53_RECORD_TYPE",
                    "TTL": 60,
                    "ResourceRecords": [
                        $FINAL_AWS_RT53_RECORD_VALUE
                    ]
                }
            }
        ]
    }
_EOT_


cat $changeResourceRecordSetsFile
$AWS --output=text route53 change-resource-record-sets --hosted-zone-id $AWS_RT53_ZONEID --change-batch "file://$changeResourceRecordSetsFile" > $changeResourceRecordSetsFile.out
rm "$changeResourceRecordSetsFile"*
