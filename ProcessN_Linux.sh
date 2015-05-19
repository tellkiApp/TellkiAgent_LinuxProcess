##########################################################################################################################################################################
## This script was developed by Guberni and is part of Tellki monitoring solution                     		       														##
##                                                                                                      	       														##
## December, 2014                     	                                                                	       														##
##                                                                                                      	       														##
## Version 1.0                                                                                          	       														##
##																									    	       														##
## DESCRIPTION: Monitor processes status and performance (CPU and memory utilization of each process)  								   									##
##																											       														##
## SYNTAX: ./ProcessN_Linux.sh <METRIC_STATE> <CIR_IDS> <PARAMS>             														       								##
##																											       														##
## EXAMPLE: ./ProcessN_Linux.sh "1,1,1,1,1" "2365" "ssh service;/usr/sbin/sshd#2"         		  																		##
##																											 	   														##
##                                      						############                                                    	 	   								##
##                                      						## README ##                                                    	 	   								##
##                                      						############                                                    	 	   								##
##																											 	   														##
## This script is used combined with runremote_Process.sh script, but you can use as standalone. 			    	 	   												##
##																											 	   														##
## runremote_Process.sh - executes input script locally or at a remove server, depending on the LOCAL parameter.	 	   												##
##																											 	   														##
## SYNTAX: sh "runremote_Process.sh" <HOST> <METRIC_STATE> <USER_NAME> <PASS_WORD> <CIR_IDS> <PARAMS> <TEMP_DIR> <SSH_KEY> <LOCAL> 	 	   								##
##																											       														##
## EXAMPLE: (LOCAL)  sh "runremote_Process.sh" "ProcessN_Linux.sh" "192.168.1.1" "1,1,1,1,1,1,1" "" "" "2365" "ssh service;/usr/sbin/sshd#1" "" "" "1"              	##
## 			(REMOTE) sh "runremote_Process.sh" "ProcessN_Linux.sh" "192.168.1.1" "1,1,1,1,1,0,0" "user" "pass" "2365" "ssh service;/usr/sbin/sshd#2" "/tmp" "null" "0"  ##
##																											 	   														##
## HOST - hostname or ip address where script will be executed.                                         	 	   														##
## METRIC_STATE - is generated internally by Tellki and its only used by Tellki default monitors.       	 	   														##
##         		  1 - metric is on ; 0 - metric is off					              						 	   														##
## USER_NAME - user name required to connect to remote host. Empty ("") for local monitoring.           	 	   														##
## PASS_WORD - password required to connect to remote host. Empty ("") for local monitoring.            	 	   														##
## CIR_IDS - (internal): only used by Tellki default monitors. Process unique cmdb ID.                   																##
## PARAMS - (internal): only used by Tellki default monitors. Process name and # of instances to check  																##
## TEMP_DIR - (remote monitoring only): directory on remote host to copy scripts before being executed.		 	   														##
## SSH_KEY - private ssh key to connect to remote host. Empty ("null") if password is used.                 	 	   													##
## LOCAL - 1: local monitoring / 0: remote monitoring                                                   	 	   														##
##########################################################################################################################################################################

#METRIC_ID
STATUSID="27:Status:9"
VMID="94:Proc Virtual Memory:4"
PMID="18:Proc Physical Memory:4"
MEMUSAGEID="92:% Proc Memory Utilization:6"
CPUUSAGEID="53:% Proc CPU Utilization:6"

#INPUTS
METRIC_STATE=$1
CIR_IDS=$2
PARAMS=$3


STATUSID_on=`echo $METRIC_STATE | awk -F',' '{print $1}'`
VMID_on=`echo $METRIC_STATE | awk -F',' '{print $2}'`
PMID_on=`echo $METRIC_STATE | awk -F',' '{print $3}'`
MEMUSAGEID_on=`echo $METRIC_STATE | awk -F',' '{print $4}'`
CPUUSAGEID_on=`echo $METRIC_STATE | awk -F',' '{print $5}'`


SCRIPT="`basename $0`"

NUMCOL=`echo $CIR_IDS | awk -F',' '{print NF}'`


# Individual processes.
for i in $(seq 1 $NUMCOL)
do
	process=`echo $PARAMS | awk -F',' '{print $'$i'}' | awk -F';' '{print $2}' | awk -F'#' '{print $1}'`
	instances=`echo $PARAMS | awk -F',' '{print $'$i'}' | awk -F'#' '{print $2}'`
	CIR_ID=`echo $CIR_IDS | awk -F',' '{print $'$i'}'`

	if [ `ps -ef|grep -w -E "$process"| grep -v $SCRIPT | grep -v grep | wc -l` -ge $instances ]
	then
	
	# Find top columns VIRT, MEM e CPU.
	TOPHEAD=`top -b -n 1 | grep PID`
	TOPCOLS=`echo $TOPHEAD | awk '{print NF}'`

	for i in $(seq 1 $TOPCOLS)
	do
		COLNAME=`echo $TOPHEAD| awk '{print $'$i'}'`
			
		if [ `echo $COLNAME | grep -c "VIRT"` -eq 1 ]
		then
			IVIRT=$i;
		fi
			
				if [ `echo $COLNAME | grep -c "CPU"` -eq 1 ]
				then
					ICPU=$i;
				fi
			
				if [ `echo $COLNAME | grep -c "MEM"` -eq 1 ]
				then
					IMEM=$i;
				fi
	done
		
			# Dirty mode.
			if [ `ps -ef|grep -w -E "$process"|grep -v grep | wc -l` -ge 20 ]
			then
				INFO_TOP=""

				for i in `ps -ef | grep -w -E "$process" | grep -v grep | awk '{print $2}'`
				do 
					INFO_TOP="$INFO_TOP\n`top -b -p $i -n 1|grep -E '^\s*[0-9]' | awk '{print $'$IVIRT'/1024,$'$ICPU',$'$IMEM' }' | grep -Ev '^0 '`"
			done
			
				INFO=`echo -e $INFO_TOP | awk '{vm+=$1;cpu+=$2;mem+=$3} END { print vm,cpu,mem}'`
			else
		
				INFO=`top -b -p $(ps -ef | grep -w "$process" | grep -v grep | awk '{print $2","}'| tr -d '\012'| sed 's/,$//g') -n 1 | grep -E '^\s*[0-9]' | awk '{print $'$IVIRT'/1024,$'$ICPU',$'$IMEM' }' | grep -Ev '^0 '| awk '{vm+=$1;cpu+=$2;mem+=$3} END { print vm,cpu,mem}'`
			fi

			if [ $VMID_on -eq 1 ]
			then
				# Virtual Memory process Mb
				VM=`echo $INFO | awk '{print $1}'`
				if [ "$VM" = "" ]
				then
					#Unable to collect metrics
					exit 8 
				fi
			fi
			if [ $PMID_on -eq 1 ]
			then
				#Process Memory usage Mb
				PID=`ps -ef | grep -w -E $process | grep -v grep | awk '{print $2," "}' | tr -d '\012' | awk '{print $1}'`
				PM=`pmap $PID | grep total |  awk '{print $2}' | sed 's/K//g' | awk '{mem+=$1/1024} END { print mem}'`
				if [ "$PM" = "" ]
				then
					#Unable to collect metrics
					exit 8 
				fi
			
			fi
			if [ $MEMUSAGEID_on -eq 1 ]
			then
				# Memory Usage %
				MEMUSAGE=`echo $INFO | awk '{print $3}'`
				if [ "$MEMUSAGE" = "" ]
				then
					#Unable to collect metrics
					exit 8 
				fi
			fi
			if [ $CPUUSAGEID_on -eq 1 ]
			then
				# CPU Usage %
				CPUUSAGE=`echo $INFO | awk '{print $2}'`
				if [ "$CPUUSAGE" = "" ]
				then
					#Unable to collect metrics
					exit 8 
				fi
			fi
			if [ $STATUSID_on -eq 1 ]
			then
				# Process status, 1= running , 0 = not running
				STATUS=1
				if [ "$STATUS" = "" ]
				then
					#Unable to collect metrics
					exit 8 
				else 
					echo "$CIR_ID|$STATUSID|$STATUS|$process|"
				fi
			fi
			# Send Metrics
			if [ $VMID_on -eq 1 ]
			then
				echo "$CIR_ID|$VMID|$VM|$process|"
			fi
			if [ $PMID_on -eq 1 ]
			then
				echo "$CIR_ID|$PMID|$PM|$process|"
			fi
			if [ $MEMUSAGEID_on -eq 1 ]
			then
				echo "$CIR_ID|$MEMUSAGEID|$MEMUSAGE|$process|"
			fi
			if [ $CPUUSAGEID_on -eq 1 ]
			then
				echo "$CIR_ID|$CPUUSAGEID|$CPUUSAGE|$process|"
			fi
			else
			if [ $STATUSID_on -eq 1 ];
			then
				# Process status, 1= running , 0 = not running
				STATUS=0
				if [ "$STATUS" = "" ]
				then
					#Unable to collect metrics
					exit 8 
				else 
					echo "$CIR_ID|$STATUSID|$STATUS|$process|"
				fi
			fi
		fi
done
	

