#!/bin/sh

LamTrustPolFil=Lambda-Role-Trust-Policy.json
LamInlinePolFil=Lambda-Role-Inline-Policy.json
StopInstCode=stop-instances.zip
StartInstCode=start-instances.zip

#Check for a valid version of python
if which python > /dev/null 2>&1;
then
    #Python is installed
    python_version=`python --version 2>&1 | awk '{print $2}'`
    python_version_parsed=$(echo "${python_version//./}")
    if [[ "$python_version_parsed" -gt "270" ]] 
    then
    	echo "Python version $python_version is installed."
    else
	echo "Python version less than 2.7.  Installed version is $python_version"
	exit
    fi

else
    #Python is not installed
    echo "No Python executable is found."
    exit
fi


awscli_version_parsed=`aws --version 2>&1 >/dev/null  | cut -d"/" -f2 | cut -d" " -f1`
awscli_major=`echo $awscli_version_parsed |awk -F. '{print $1}'`
awscli_minor=`echo $awscli_version_parsed |awk -F. '{print $2}'`

if which aws > /dev/null 2>&1;
then
    if [ "$awscli_major" -ge "1" ]
    then
        if [ "$awscli_minor" -lt "10" ]
        then
	    echo Running an older version of AWS cli [$awscli_version_parsed] please upgrade
            exit
        else
            echo AWS CLI version $awscli_version_parsed installed
        fi
    else
        echo Running an older version of the AWS cli [$awscli_version_parsed] please upgrade
        exit
    fi
else
    echo AWS cli is not installed, Please install.
    exit
fi

if LamPolArn=`aws iam get-role --role-name Sched-Instances-Lambda-Role --query 'Role.Arn'| sed -e 's/^"//' -e 's/"$//' 2>&1 >/dev/null `; then
  echo '*** Role "Sched-Instances-Lambda-Role" already created'
else
  if [ -f "$LamTrustPolFil" ] ; then
	#Create Lambda Trust Policy
	aws iam create-role --role-name Sched-Instances-Lambda-Role \
	--assume-role-policy-document file://$LamTrustPolFil
  else
	echo "Unable to find $LamTrustPolFil file"
	exit
  fi

  if [ -f "$LamInlinePolFil" ] ; then
	#Create Lambda Inline Policy
	aws iam put-role-policy --role-name Sched-Instances-Lambda-Role \
	--policy-name Schedule-Instances-Policy \
	--policy-document file://$LamInlinePolFil
  else
	echo "Unable to find $LamInlinePolFil file"
	exit
  fi
fi

#store lambda policy arn in variable
LamPolArn=`aws iam get-role --role-name Sched-Instances-Lambda-Role --query 'Role.Arn'| sed -e 's/^"//' -e 's/"$//'`
#echo $LamPolArn

if StopInstArn=`aws lambda get-function --function-name stop-instances --query 'Configuration.FunctionArn'|sed -e 's/^"//' -e 's/"$//'`; then
   echo '*** stop-instances lambda script already exists'
else
   #create stop instance lambda function
   if [ -f $StopInstCode ] ; then
	aws lambda create-function \
	--function-name stop-instances \
	--zip-file fileb://$StopInstCode \
	--runtime python2.7 \
	--role $LamPolArn \
	--handler stop-instances.lambda_handler \
	--timeout 60
        #StopInstArn=`aws lambda get-function --function-name stop-instances --query 'Configuration.FunctionArn'|sed -e 's/^"//' -e 's/"$//'`
   else
	echo "Unable to find $StopInstCode file"
	exit
   fi
fi

StopInstArn=`aws lambda get-function --function-name stop-instances --query 'Configuration.FunctionArn'|sed -e 's/^"//' -e 's/"$//'`

if StartInstArn=`aws lambda get-function --function-name start-instances --query 'Configuration.FunctionArn'|sed -e 's/^"//' -e 's/"$//'`; then
   echo '*** start-instances lambda script already exists'
else
   #create start instance lambda function
   if [ -f $StartInstCode ] ; then
	aws lambda create-function \
	--function-name start-instances \
	--zip-file fileb://$StartInstCode \
	--runtime python2.7 \
	--role $LamPolArn \
	--handler start-instances.lambda_handler \
	--timeout 60
   else
	echo "Unable to find $StartInstCode file"
	exit
  fi
fi

StartInstArn=`aws lambda get-function --function-name start-instances --query 'Configuration.FunctionArn'|sed -e 's/^"//' -e 's/"$//'`
#echo $StartInstArn

#Create cloudwatch scheduled event source to stop
if aws events list-rules --query 'Rules[*].Name' |grep StopEvent5pmEst 2>&1 >/dev/null; then
   echo '*** StopEvent5pmEst cloudwatch event already exists'
else
   aws events put-rule --schedule-expression 'cron(0 21 ? * MON-FRI *)' --name StopEvent5pmEst
fi
StopEvntSrcArn=`aws events describe-rule --name=StopEvent5pmEst --query 'Arn'|sed -e 's/^"//' -e 's/"$//'`
#echo $StopEvntSrcArn

#Create cloudwatch scheduled event source to start
if aws events list-rules --query 'Rules[*].Name' |grep StartEvent7amEst 2>&1 >/dev/null; then
   echo '*** StartEvent7amEst cloudwatch event already exists'
else    
   aws events put-rule --schedule-expression 'cron(0 11 ? * MON-FRI *)' --name StartEvent7amEst
fi

StartEvntSrcArn=`aws events describe-rule --name=StartEvent7amEst --query 'Arn'|sed -e 's/^"//' -e 's/"$//'`
#echo $StartEvntSrcArn


#Add permissions to allow event source to excute lambda function
aws lambda add-permission --function-name stop-instances \
--statement-id stop-instances --action 'lambda:InvokeFunction' \
--principal events.amazonaws.com \
--source-arn $StopEvntSrcArn

#Add permissions to allow event source to excute lambda function
aws lambda add-permission --function-name start-instances \
--statement-id start-instances --action 'lambda:InvokeFunction' \
--principal events.amazonaws.com \
--source-arn $StartEvntSrcArn

#Associate event rule with lambda function
aws events put-targets \
--rule StopEvent5pmEst \
--targets '{"Id" : "1", "Arn": "'$StopInstArn'"}'

#Associate event rule with lambda function
aws events put-targets \
--rule StartEvent7amEst \
--targets '{"Id" : "1", "Arn": "'$StartInstArn'"}'


echo '\n'ARN REPORT:'\n'
echo Lambda Policy ARN:'\t\t'$LamPolArn
echo Lambda Stop Function ARN:'\t'$StopInstArn
echo Lambda Start Function ARN:'\t'$StartInstArn
echo Stop Event Source ARN:'\t\t'$StopEvntSrcArn
echo Start Event Source ARN:'\t\t'$StartEvntSrcArn
