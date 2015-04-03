#!/bin/sh
#
# Script to pull temporary credentials from instance metadata
#
############################################################
PATH=/bin:/usr/bin:/opt/AWScli/bin

IAMROLE=Instance-BAR

# Get session auth tokens
for AWSENV in `curl -s http://169.254.169.254/latest/meta-data/iam/security-credentials/${IAMROLE} | sed '{
   s/^.*AccessKeyId" : "/AWS_ACCESS_KEY_ID=/
   s/^.*"SecretAccessKey" : "/AWS_SECRET_ACCESS_KEY=/
   s/^.*"Token" : "/AWS_SESSION_TOKEN=/
   s/",$//
   /" : "/d
   /{/d
   /\}/d
}'`;
do
   export ${AWSENV}
done

AZ=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
AWS_DEFAULT_REGION=$(echo ${AZ} | sed 's/[a-z]*$//')

export AWS_DEFAULT_REGION

aws ec2 describe-instances

env | grep AWS
