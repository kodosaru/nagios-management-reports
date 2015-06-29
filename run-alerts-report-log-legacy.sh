#!/bin/bash
# 20150213 djohnson
# 20150623 djohnson Added print recovery line selector

# Set this start date if debugging reports
start_date="06/11/2015"
echo "Report start date:" $start_date

# Set if cronjob
#CRON_JOB=true
CRON_JOB=false

# Set debugging to true if want diagnostics sent to stdout
DEBUG=true
#DEBUG=false

# Set if recovery line is printed 
RECOVERY=true
#RECOVERY=false

# Force deliverly if want to send report out to actual users in debugging mode
# Report not normally sent to actual users in debugging mode
#FORCE_DELIVER=true
FORCE_DELIVER=false

# Set if you want to send mail
MAIL=true
#MAIL=false

# Set if you want to use send the reports that already exist in the nagios-management-reports
# home directory
#SKIP_RPT_GEN=true
SKIP_RPT_GEN=false

# Send a special message in the body of the email
SPEC_MSG=true
#SPEC_MSG=false

# Choose if you want to send mail
if [ $MAIL == "true" ]; then
	mutt_path='/usr/bin/mutt -F /usr/local/nagios-management-reports/muttrc'
else
	mutt_path='/bin/true'
fi

if [ $SKIP_RPT_GEN == "false" ]; then
	# Generate all three reports: Unix, Windows and Other 
	#os_list="unix"
	os_list="unix windows dba other"

	for os in $os_list 
	do
		echo "OS: "$os
		./alerts-report.rb $start_date $CRON_JOB $DEBUG $RECOVERY $os
		echo "./alerts-report.rb $start_date $CRON_JOB $DEBUG $RECOVERY $os"
	done
fi

if [ $RECOVERY == "true" ]
then 
	unix_filename_with_recovery=`/bin/ls -ltr | /bin/awk '{print $9}' | /bin/egrep '^unix_alerts_with_recovery_[0-9]{2}-[0-9]{2}_to_[0-9]{2}-[0-9]{2}.xls'`
	windows_filename_with_recovery=`/bin/ls -ltr | /bin/awk '{print $9}' | /bin/egrep '^windows_alerts_with_recovery_[0-9]{2}-[0-9]{2}_to_[0-9]{2}-[0-9]{2}.xls'`
	dba_filename_with_recovery=`/bin/ls -ltr | /bin/awk '{print $9}' | /bin/egrep '^dba_alerts_with_recovery_[0-9]{2}-[0-9]{2}_to_[0-9]{2}-[0-9]{2}.xls'`
	other_filename_with_recovery=`/bin/ls -ltr | /bin/awk '{print $9}' | /bin/egrep '^other_alerts_with_recovery_[0-9]{2}-[0-9]{2}_to_[0-9]{2}-[0-9]{2}.xls'`

	if [ $DEBUG == "true" ]; then
		echo
		echo Report files creation validation:
		echo "Unix file name with recovery: "$unix_filename_with_recovery
		echo "Windows file name with recovery: "$windows_filename_with_recovery
		echo "DBA file name with recovery: "$dba_filename_with_recovery
		echo "Other file name with recovery: "$other_filename_with_recovery
		if [ -f "$unix_filename_with_recovery" ]
		then
			echo Unix with recovery report created
		else
			echo No Unix with recovery report created
		fi
		if [ -f "$windows_filename_with_recovery" ]
		then
			echo Windows with recovery report created
		else
			echo No Windows with recovery report created
		fi
		if [ -f "$dba_filename_with_recovery" ]
		then
			echo DBA with recovery report created
		else
			echo No DBA with recovery report created
		fi
		if [ -f "$other_filename_with_recovery" ]
		then
			echo Other with recovery report created
		else
			echo No Other with recovery report created
		fi
	fi
else
	unix_filename=`/bin/ls -ltr | /bin/awk '{print $9}' | /bin/egrep '^unix_alerts_[0-9]{2}-[0-9]{2}_to_[0-9]{2}-[0-9]{2}.xls'`
	windows_filename=`/bin/ls -ltr | /bin/awk '{print $9}' | /bin/egrep '^windows_alerts_[0-9]{2}-[0-9]{2}_to_[0-9]{2}-[0-9]{2}.xls'`
	dba_filename=`/bin/ls -ltr | /bin/awk '{print $9}' | /bin/egrep '^dba_alerts_[0-9]{2}-[0-9]{2}_to_[0-9]{2}-[0-9]{2}.xls'`
	other_filename=`/bin/ls -ltr | /bin/awk '{print $9}' | /bin/egrep '^other_alerts_[0-9]{2}-[0-9]{2}_to_[0-9]{2}-[0-9]{2}.xls'`

	if [ $DEBUG == "true" ]; then
		echo
		echo Report files creation validation:
		echo "Unix file name: "$unix_filename
		echo "Windows file name: "$windows_filename
		echo "DBA file name: "$dba_filename
		echo "Other file name: "$other_filename
		echo
		if [ -f "$unix_filename" ]
		then
			echo Standard Unix report created
		else
			echo No standard Unix report created
		fi
		if [ -f "$windows_filename" ]
		then
			echo Standard Windows report created
		else
			echo No standard Windows report created
		fi
		if [ -f "$dba_filename" ]
		then
			echo Standard DBA report created
		else
			echo No standard DBA report created
		fi
		if [ -f "$other_filename" ]
		then
			echo Standard Other report created
		else
			echo No standard Other report created
		fi
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
if [ -n "$unix_filename_with_recovery" ]
then
	MANAGER_MAIL_CMD+=" -a "$unix_filename_with_recovery
fi
if [ -n "$windows_filename" ]
then
	MANAGER_MAIL_CMD+=" -a "$windows_filename
fi
if [ -n "$windows_filename_with_recovery" ]
then
	MANAGER_MAIL_CMD+=" -a "$windows_filename_with_recovery
fi
if [ -n "$dba_filename" ]
then
	MANAGER_MAIL_CMD+=" -a "$dba_filename
fi
if [ -n "$dba_filename_with_recovery" ]
then
	MANAGER_MAIL_CMD+=" -a "$dba_filename_with_recovery
fi
if [ -n "$other_filename" ]
then
	MANAGER_MAIL_CMD+=" -a "$other_filename
fi
if [ -n "$other_filename_with_recovery" ]
then
	MANAGER_MAIL_CMD+=" -a "$other_filename_with_recovery
fi
MMC_LEN=${#MANAGER_MAIL_CMD}

echo
# Generate the Linux team report
if [ -n "$unix_filename_with_recovery" ]
then
	if [ $DEBUG == "true" ]
	then
		printf "\nSending Linux report\n"
	fi
	BODY="linux_team_body"$BODY_SUFFIX".txt"
	while read recipient 
	do
		if [ -z "`echo $recipient | egrep '^.*#'`" ]; then
			if [ $DEBUG == "true" ]; then
				echo cat $BODY \| $mutt_path -s "Unix Duty Pager Alerts Report" -a $unix_filename_with_recovery -- $recipient
			fi
			cat $BODY | $mutt_path -s "Unix Duty Pager Alerts Report" -a $unix_filename_with_recovery -- $recipient
		fi
	done < $LINUX_TEAM_LIST
else
			echo 'echo "No alert records found this week." | $mutt_path -s "Unix Duty Pager Alerts Report" -a $unix_filename_with_recovery -- $recipient'
			echo "No alert records found this week." | $mutt_path -s "Unix Duty Pager Alerts Report" -a $unix_filename_with_recovery -- $recipient
fi

# Generate the Windows team report
if [ -n "$windows_filename_with_recovery" ]
then
	if [ $DEBUG == "true" ]
	then
		printf "\nSending Windows's report\n"
	fi
	BODY="windows_team_body"$BODY_SUFFIX".txt"
	while read recipient 
	do
		if [ -z "`echo $recipient | egrep '^.*#'`" ]; then
			if [ $DEBUG == "true" ]; then
				echo cat $BODY \| $mutt_path -s "Windows Duty Pager Alerts Report" -a $windows_filename_with_recovery -- $recipient 
			fi
			cat $BODY | $mutt_path -s "Windows Duty Pager Alerts Report" -a $windows_filename_with_recovery -- $recipient 
		fi
	done < $WINDOWS_TEAM_LIST
else
			echo 'echo "No alert records found this week." | $mutt_path -s "Windows Duty Pager Alerts Report" -a $windows_filename_with_recovery -- $recipient'
			echo "No alert records found this week." | $mutt_path -s "Windows Duty Pager Alerts Report" -a $windows_filename_with_recovery -- $recipient 
fi

# Generate the DBA report
if [ -n "$dba_filename_with_recovery" ]
then
	if [ $DEBUG == "true" ]
	then
		printf "\nSending DBAs' report\n"
	fi
	BODY="dba_team_body"$BODY_SUFFIX".txt"
	while read recipient 
	do
		if [ -z "`echo $recipient | egrep '^.*#'`" ]; then
			if [ $DEBUG == "true" ]; then
				echo cat $BODY \| $mutt_path -s "DBA Duty Pager Alerts Report" -a $dba_filename_with_recovery -- $recipient 
			fi
			cat $BODY | $mutt_path -s "DBA Duty Pager Alerts Report" -a $dba_filename_with_recovery -- $recipient 
		fi
	done < $DBA_TEAM_LIST
else
		echo 'echo "No alert records found this week."  | $mutt_path -s "DBA Duty Pager Alerts Report" -a $dba_filename_with_recovery -- $recipient'
		echo "No alert records found this week."  | $mutt_path -s "DBA Duty Pager Alerts Report" -a $dba_filename_with_recovery -- $recipient 
fi

# Generate the other report
if [ -n "$other_filename_with_recovery" ]
then
	if [ $DEBUG == "true" ]
	then
		printf "\nSending Other's report\n"
	fi
	BODY="other_team_body"$BODY_SUFFIX".txt"
	while read recipient 
	do
		if [ -z "`echo $recipient | egrep '^.*#'`" ]; then
			if [ $DEBUG == "true" ]; then
				echo cat $BODY \| $mutt_path -s "Other Duty Pager Alerts Report" -a $other_filename_with_recovery -- $recipient 
			fi
			cat $BODY | $mutt_path -s "Other Duty Pager Alerts Report" -a $other_filename_with_recovery -- $recipient 
		fi
	done < $OTHER_TEAM_LIST
else
		echo 'echo "No alert records found this week." | $mutt_path -s "Other Duty Pager Alerts Report" -a $other_filename_with_recovery -- $recipient' 
		echo "No alert records found this week." | $mutt_path -s "Other Duty Pager Alerts Report" -a $other_filename_with_recovery -- $recipient 
fi

# Generate the managers report
if [ -n "$unix_filename_with_recovery" ] && [ -n "$windows_filename_with_recovery" ] \
   	&& [ -n "$dba_filename_with_recovery" ] && [ -n "$other_filename_with_recovery" ] 
then
	if [ $DEBUG == "true" ]
	then
		printf "\nSending Managers' report\n"
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
else
	echo 'echo "No alert records found this week." | $mutt_path -s "Manager Duty Pager Alerts Reports" -- $recipient'
	echo "No alert records found this week." | $mutt_path -s "Manager Duty Pager Alerts Reports" -- $recipient
fi

# Archive the reports
if [ $DEBUG == "false" ] || [ $FORCE_DELIVER == "true" ]; then
	mv *.xls ./reports/
fi
