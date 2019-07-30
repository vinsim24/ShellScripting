#!/bin/bash
set -e

AWS=/usr/bin/aws

tableName="$1"

if [ -z "$tableName" ]; then
	echo "Usage: $0 <table name> [outputFile]"
	echo "e.g. $0 dummy-table-name"
	exit 1
fi

outputFile=${2:-$tableName.json}
$AWS --region $AWS_REGION --output json dynamodb scan --table-name "$tableName" > $outputFile



