#!/usr/bin/bash

# This script is used for removing the home directory of one or more users
# You'll need to provide a list of servers and a list of the users to be removed.

## ENVIRONMENT

# General variables
WORKING_PATH=`dirname "$0"`
suffix=`echo $(date +%d%m%y)`
log_dir=$WORKING_PATH/logs/remHomeDir

if [ $WORKING_PATH = "." ]
then WORKING_PATH=`pwd`
fi

# Functions

# verify if the given file exists and if it is populated

function file_check
{
if [ ! -f $1 ] 
then 
echo "$1 does not exist; exiting the script"
exit
else 
if [ `wc -l $1 | awk '{print $1}'` == 0 ]
then echo "File $1 is empty. Exiting the script"
fi # empty
fi # exists
}

# get the homedir of the user from AD

function home_dir
{
local homedir
OS=`uname`
if [ $OS = "HP-UX" ]
then 
homedir=`nsquery passwd $1 | grep -i home | awk '{print $3}'`
else homedir=`getent passwd $1 | awk -F ":" '{print $6}'`
fi
echo $homedir
}


## INPUT DATA and verification

# List of users

echo "User list:"
read ulist

file_check $ulist

echo "List of users look ok"

# List of servers

echo "Server list (enter ALL if you want to check all the servers):"
read slist

if [ $slist = "ALL" ]
then echo "You chose to check on all servers"
ORIG_SLIST=/scs/system/data/master_server_list/master_server_list
TMP_SLIST=$WORKING_PATH/servers_tmp.txt
awk -F ":" '{print $1}' $ORIG_SLIST | awk -F "." '{print $1}' | tr '[:upper:]' '[:lower:]' | sort -u | grep -iv kevin > $TMP_SLIST
slist=$TMP_SLIST
fi
  
file_check $slist

echo "List of servers looks ok"

## MAIN

nrtotsrv=`wc -l $slist | awk '{print $1}'`
nrtotusr=`wc -l $ulist | awk '{print $1}'`
nrcrtusr=0


for i in `cat $ulist`
do

echo " "
nrcrtusr=$(( nrcrtusr + 1 ))
nrcrtsrv=0
echo "User $nrcrtusr of $nrtotusr: $i"
echo "" | tee -a $log_dir/$i.$suffix.log

# Checks if user exists in AD

id $i &>/dev/null

if (( $? != 0 ))
then echo "User $i does not exist, moving on to the next one"
break
fi

homedir=$(home_dir $i)

for j in `cat $slist`
do
nrcrtsrv=$(( nrcrtsrv + 1 ))
echo "$nrcrtusr/$nrtotusr - Server $nrcrtsrv of $nrtotsrv: $j"

ssh -q -o StrictHostKeyChecking=no -o ConnectTimeout=3 $j uptime &>/dev/null
if (( $? == 255 ))
then echo "Server is DOWN, moving forward"
else
ssh -q -o ConnectTimeout=3 $j "ls -ld $homedir" &>/dev/null
if (( $? == 2 ))
then echo "User does not have homedir on the server"
else echo "Homedir of $i is present on $j"
#if (( $presence == 1 ))
#then echo "User $i has a home dir on $j. Removing..." | tee -a $log_dir/$i.$suffix.log

fi # Check if user is present on the server
fi # Check if server is up


done # Servers list

done # Users list
