#!/bin/bash

name=$1

if [ -z "$name" ]; then
    echo "Usage: $0 <name>"
    echo "E.g.,: $0 name"
    exit 1
fi

OAI_ID=$(/usr/bin/aws cloudfront list-cloud-front-origin-access-identities --query "CloudFrontOriginAccessIdentityList.Items[?contains(Comment, \`$name\`) == \`true\`].{Id:Id}" --output text)

echo "{ \"oaiId\": \"$OAI_ID\" }"
