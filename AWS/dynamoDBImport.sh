#!/bin/bash
set -e

AWS=/usr/bin/aws

tableName="$1"

if [ -z "$tableName" ]; then
	echo "Usage: $0 <table name> [inputFile]"
	echo "e.g. $0 dummy-table-name"
	exit 1
fi

inputFile=${2:-$tableName.json}
finalInputFile="$tableName-import.json"

itemsLength=$(cat "$inputFile" | jq ".Items | length" )

if [ "$itemsLength" -eq 0 ];then
    echo "No items to import"
    exit
fi

cat "$inputFile" | jq "{\""$tableName"\": [.Items[] | {PutRequest: {Item: .}}]}" > "$finalInputFile"


putItemsLength=$(cat $finalInputFile | jq --arg k "$tableName" '.[$k]'  | jq length )

lowerLimit=0
upperLimit=0
increment=25
breakLoop="false"
count=0
while true;
do
    count=$(($count+1))
    tmpFileName="tmpFile-$count.json"

    upperLimit=$(( lowerLimit + increment ))

    if [[ ${upperLimit} -gt ${putItemsLength} ]];then
        upperLimit=${putItemsLength}
        breakLoop="true"
    fi

    cat $finalInputFile | jq --arg tableName "$tableName" --argjson lowerLimit "$lowerLimit" --argjson upperLimit "$upperLimit" '.[$tableName][$lowerLimit:$upperLimit]' | jq "{\""$tableName"\": .}" > "$tmpFileName"
    #echo "Import JSON -- "
    #cat "$tmpFileName"
    echo $AWS --region $AWS_REGION --output json dynamodb batch-write-item --request-items file://$tmpFileName
    $AWS --region $AWS_REGION --output json dynamodb batch-write-item --request-items file://$tmpFileName

    if [[ "$breakLoop" == "true" ]];then
         break
    fi

   lowerLimit=${upperLimit}

done

rm $finalInputFile
rm tmpFile*
