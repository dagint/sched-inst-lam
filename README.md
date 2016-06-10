# sched-inst-lam
Script to perform setup and configuration to schedule AWS EC2 instances.  Script filters instances based on the tag "AutoOff" equal to "True" (no quotes) and is set to start instances at 7am EST and turn off at 5pm EST.  This script is based on the following blog post below, but just automating each of the steps.

Reference: https://www.nimbo.com/blog/automating-ec2-tasks-with-aws-lambda/

## Prerequisities
- requires python 2.6.5 or above
- python would need to be in the path
- Most recent version of aws cli.  1.10.17 currently works with this script
- Your AWS CLI credentails configured for a user with rights to perform steps outlined in the reference url above
- all files included should be in the same directory as the script sched-inst-iam.sh

## Included Files
- README.md
- Lambda-Role-Inline-Policy.json (file needed to create inline IAM policy)
- Lambda-Role-Trust-Policy.json (file needed to create Trust IAM policy)
- sched-inst-lam.sh (Script which performs the installation steps)
- start-instances.py (Python code used to start instances, not used in install script)
- start-instances.zip (zip file which includes the py file above to perform install)
- stop-instances.py (Python code used to stop instacnes, not used in install script)
- stop-instances.zip (zip file which includes py file above to perform install)    

## Installing
all files need to be in the same folder

```
chmod 755 sched-inst-lam.sh
./sched-inst-lam.sh
```
         
