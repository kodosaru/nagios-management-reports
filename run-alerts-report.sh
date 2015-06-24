#!/bin/bash
# 20150213 djohnson
# 20150623 djohnson Added print recovery line selector
# 20150624 djohnson Made changes to support new report that runs
#                   against database instead of logs 

# Set the destination directory for the reports
report_destination="/usr/local/nagios-management-reports"

# Set if cronjob
CRON_JOB=true
#CRON_JOB=false

# Set debugging to true if want diagnostics sent to stdout
#DEBUG=true
DEBUG=false

# Set pager hand-off time
pager_handoff="10:00"

# Set this start and end time for EST military time if debugging reports
if [ $CRON_JOB == "true" ]; then
	# If cron job, used now date for start and 7 days later for end
	# Use pager handoff time for cutoff 
	start_time=`date '+%m/%d/%Y' -d '-7 days'`
	start_time=$start_time" "$pager_handoff
	end_time=`date '+%m/%d/%Y'`
	end_time=$end_time" "$pager_handoff
else
	start_time="06/10/2015 21:03"
	end_time="06/17/2015 17:54"
fi

if [ $DEBUG == "true" ];then
	echo "Report period start: "$start_time
	echo "Report period end: "$end_time
fi

# Set if recovery line is printed 
RECOVERY=true
#RECOVERY=false

# Force deliverly if want to send report out to actual users in debugging mode
# Report not normally sent to actual users in debugging mode
#FORCE_DELIVER=true
FORCE_DELIVER=false

# Set if you want to send mail
#MAIL=true
MAIL=false

# Set if you want to use send the reports that already exist in the nagios-management-reports
# home directory
#SKIP_RPT_GEN=true
SKIP_RPT_GEN=false

# Send a special message in the body of the email
SPEC_MSG=true
#SPEC_MSG=false

cwd=`/bin/pwd`
# Choose if you want to send mail
if [ $MAIL == "true" ]; then
	mutt_path="/usr/bin/mutt -F $cwd"/"muttrc"
else
	mutt_path="/bin/true"
fi

if [ $SKIP_RPT_GEN == "false" ]; then
	# Generate all three reports: Unix, Windows and Other 
	#os_list="unix"
	os_list="unix windows dba other"

	for os in $os_list 
	do
		./alerts-report.rb "$start_time" "$end_time" $DEBUG $RECOVERY $os
	done
fi

regex='_[0-9]{2}-[0-9]{2}-[0-9]{4}_[0-9:]{5}_to_[0-9]{2}-[0-9]{2}-[0-9]{4}_[0-9:]{5}_EST.xls'
if [ $RECOVERY == "true" ]
then 
	unix_filename=`/bin/find  $report_destination | /bin/egrep '^.+unix_alerts_with_recovery'$regex`
	windows_filename=`/bin/find  $report_destination | /bin/egrep '^.+windows_alerts_with_recovery'$regex`
	dba_filename=`/bin/find  $report_destination | /bin/egrep '^.+dba_alerts_with_recovery'$regex`
	other_filename=`/bin/find  $report_destination | /bin/egrep '^.+other_alerts_with_recovery'$regex`
else
	unix_filename=`/bin/find  $report_destination | /bin/egrep '^.+unix_alerts'$regex`
	windows_filename=`/bin/find  $report_destination | /bin/egrep '^.+windows'$regex`
	dba_filename=`/bin/find  $report_destination | /bin/egrep '^.+dba_alerts'$regex`
	other_filename=`/bin/find  $report_destination | /bin/egrep '^.+other_alerts'$regex`
fi

if [ $DEBUG == "true" ]; then
	if [ -f "$unix_filename" ]
	then
		echo Unix report created: $unix_filename
	else
		echo No Unix report created
	fi
	if [ -f "$windows_filename" ]
	then
		echo Windows report created: $windows_filename
	else
		echo No Windows report created
	fi
	if [ -f "$dba_filename" ]
	then
		echo DBA report created: $dba_filename
	else
		echo No DBA report created
	fi
	if [ -f "$other_filename" ]
	then
		echo Other report created: $other_filename
	else
		echo No Other report created
	fi
fi

# Define mailing lists
if [ $DEBUG == "true" ] && [ $FORCE_DELIVER == "false" ]; then
	LINUX_TEAM_LIST=test.list
	WINDOWS_TEAM_LIST=test.list
	DBA_TEAM_LIST=test.list
	OTHER_TEAM_LIST=test.list
	MANAGERS_LIST=test.list
else
	LINUX_TEAM_LIST=linux_team.list
	WINDOWS_TEAM_LIST=windows_team.list
	DBA_TEAM_LIST=dba_team.list
	OTHER_TEAM_LIST=other_team.list
	MANAGERS_LIST=managers.list
fi

if [ $SPEC_MSG == "true" ]; then
	BODY_SUFFIX="_special"
else
	BODY_SUFFIX=""
fi

BODY="managers_body"$BODY_SUFFIX".txt"
MANAGER_MAIL_CMD="cat $BODY | $mutt_path -s \"Manager Duty Pager Alerts Reports\""
MMC_LEN=${#MANAGER_MAIL_CMD}
if [ -n "$unix_filename" ]
then
	MANAGER_MAIL_CMD+=" -a "$unix_filename
fi
if [ -n "$unix_filename" ]
then
	MANAGER_MAIL_CMD+=" -a "$unix_filename
fi
if [ -n "$windows_filename" ]
then
	MANAGER_MAIL_CMD+=" -a "$windows_filename
fi
if [ -n "$windows_filename" ]
then
	MANAGER_MAIL_CMD+=" -a "$windows_filename
fi
if [ -n "$dba_filename" ]
then
	MANAGER_MAIL_CMD+=" -a "$dba_filename
fi
if [ -n "$dba_filename" ]
then
	MANAGER_MAIL_CMD+=" -a "$dba_filename
fi
if [ -n "$other_filename" ]
then
	MANAGER_MAIL_CMD+=" -a "$other_filename
fi
if [ -n "$other_filename" ]
then
	MANAGER_MAIL_CMD+=" -a "$other_filename
fi
MMC_LEN=${#MANAGER_MAIL_CMD}

# Send the Linux team report
if [ -n "$unix_filename" ]
then
	if [ $DEBUG == "true" ]
	then
		printf "\nSending the Linux report\n"
	fi
	BODY="linux_team_body"$BODY_SUFFIX".txt"
	while read recipient 
	do
		if [ -z "`echo $recipient | egrep '^.*#'`" ]; then
			if [ $DEBUG == "true" ]; then
				echo cat $BODY \| $mutt_path -s "Unix Duty Pager Alerts Report" -a $unix_filename -- $recipient
			fi
			cat $BODY | $mutt_path -s "Unix Duty Pager Alerts Report" -a $unix_filename -- $recipient
		fi
	done < $LINUX_TEAM_LIST
fi

# Send the Windows team report
if [ -n "$windows_filename" ]
then
	if [ $DEBUG == "true" ]
	then
		printf "\nSending the Windows's report\n"
	fi
	BODY="windows_team_body"$BODY_SUFFIX".txt"
	while read recipient 
	do
		if [ -z "`echo $recipient | egrep '^.*#'`" ]; then
			if [ $DEBUG == "true" ]; then
				echo cat $BODY \| $mutt_path -s "Windows Duty Pager Alerts Report" -a $windows_filename -- $recipient 
			fi
			cat $BODY | $mutt_path -s "Windows Duty Pager Alerts Report" -a $windows_filename -- $recipient 
		fi
	done < $WINDOWS_TEAM_LIST
fi

# Send the DBA report
if [ -n "$dba_filename" ]
then
	if [ $DEBUG == "true" ]
	then
		printf "\nSending the DBAs' report\n"
	fi
	BODY="dba_team_body"$BODY_SUFFIX".txt"
	while read recipient 
	do
		if [ -z "`echo $recipient | egrep '^.*#'`" ]; then
			if [ $DEBUG == "true" ]; then
				echo cat $BODY \| $mutt_path -s "DBA Duty Pager Alerts Report" -a $dba_filename -- $recipient 
			fi
			cat $BODY | $mutt_path -s "DBA Duty Pager Alerts Report" -a $dba_filename -- $recipient 
		fi
	done < $DBA_TEAM_LIST
fi

# Send the other report
if [ -n "$other_filename" ]
then
	if [ $DEBUG == "true" ]
	then
		printf "\nSending the Other's report\n"
	fi
	BODY="other_team_body"$BODY_SUFFIX".txt"
	while read recipient 
	do
		if [ -z "`echo $recipient | egrep '^.*#'`" ]; then
			if [ $DEBUG == "true" ]; then
				echo cat $BODY \| $mutt_path -s "Other Duty Pager Alerts Report" -a $other_filename -- $recipient 
			fi
			cat $BODY | $mutt_path -s "Other Duty Pager Alerts Report" -a $other_filename -- $recipient 
		fi
	done < $OTHER_TEAM_LIST
fi

# Send the managers report
if [ -n "$unix_filename" ] && [ -n "$dba_filename" ] && [ -n "$dba_filename" ] && [ -n "$other_filename" ]
then
	if [ $DEBUG == "true" ]
	then
		printf "\nSending the Managers' report\n"
	fi
	while read recipient 
	do
		if [ -z "`echo $recipient | egrep '^.*#'`" ]; then
			if [ $DEBUG == "true" ]; then
				echo $MANAGER_MAIL_CMD" -- "$recipient 
			fi
			eval $MANAGER_MAIL_CMD" -- "$recipient 
		fi
	done < $MANAGERS_LIST
fi

# Archive the reports
if [ $DEBUG == "false" ] || [ $FORCE_DELIVER == "true" ]; then
	if [ ! -d $cwd"/reports/" ]; then
		mkdir $cwd"/reports/"
	fi
	mv $cwd"/"*.xls $cwd"/reports/"
fi
