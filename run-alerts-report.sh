#!/bin/bash
# 20150213 djohnson
# 20150623 djohnson Added print recovery line selector
# 20150624 djohnson Made changes to support new report that runs
#                   against database instead of logs 
# 20150702 djohnson Added India team

# Set the destination directory for the reports
report_home="/usr/local/nagios-management-reports"
log_file="/var/log/nagios-management-reports/`date +%Y%m%d_%H%M.log`"

# Set if cronjob
CRON_JOB=true
#CRON_JOB=false

# Set debugging to true if want diagnostics sent to stdout
#DEBUG=true
DEBUG=false

# Set pager hand-off time in UTC
pager_handoff1="14:00"
pager_handoff2="13:59"

# Set this start and end time if debugging reports
if [ $CRON_JOB == "true" ]; then
	# If cron job, used now date in UTC for start and 7 days later for end
	# Use pager handoff time for cutoffs 
	start_time=`TZ=UTC date '+%m/%d/%Y' -d '-7 days'`
	start_time=$start_time" "$pager_handoff1
	end_time=`TZ=UTC date '+%m/%d/%Y'`
	end_time=$end_time" "$pager_handoff2
else
    # This start and end time assignment must be in UTC because report can
	# output time/date for different time zone and uses this as a reference
	# Example UTC equals EST +4 hours for summer daylight savings time (+5 for winter) 
	# EST is actually EDT if using daylight savings time
	start_time="06/25/2015 14:00"
	end_time="07/02/2015 13:59"
fi

# Set if recovery line is printed 
RECOVERY=true
#RECOVERY=false

# Force delivery if want to send report out to actual users in debugging mode
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
#SPEC_MSG=true
SPEC_MSG=false

# Choose if you want to send mail
if [ $MAIL == "true" ]; then
	mutt_path="/usr/bin/mutt -F $report_home"/"muttrc"
else
	mutt_path="/bin/true"
fi

ruby_script="alerts-report.rb"

# Define mailing lists
if [ $DEBUG == "true" ] && [ $FORCE_DELIVER == "false" ]; then
	LINUX_TEAM_LIST=test.list
	LINUX_TEAM_LIST_CET=test.list
	LINUX_TEAM_LIST_IST=test.list
	WINDOWS_TEAM_LIST=test.list
	DBA_TEAM_LIST=test.list
	OTHER_TEAM_LIST=test.list
	MANAGERS_LIST=test.list
else
	LINUX_TEAM_LIST=linux_team.list
	LINUX_TEAM_LIST_CET=linux_team_cet.list
	LINUX_TEAM_LIST_IST=linux_team_ist.list
	WINDOWS_TEAM_LIST=windows_team.list
	DBA_TEAM_LIST=dba_team.list
	OTHER_TEAM_LIST=other_team.list
	MANAGERS_LIST=managers.list
fi

# Set the time zone for output
TIME_ZONE="Eastern Time (US & Canada)"
#TIME_ZONE="Europe/Berlin"
#TIME_ZONE="Europe/Paris"
#TIME_ZONE="Europe/Rome"

if [ $DEBUG == "true" ]; then
	system_tz=`cat /etc/sysconfig/clock | sed 's/^ZONE="\(.*\)"/\1/'` 
	printf "Values requested in BASH script:\n"
	if [ $CRON_JOB == "true" ]; then
		printf "\tRun in cronjob mode setting report period automatically\n"
	else
		printf "\tRun in non-cronjob mode\n"
	fi
	printf "\tSystem time zone: \"%s\" - Linux format\n" "$system_tz"
	printf "\tSystem local time: %s\n" "`date`"
	printf "\tRequested start time (UTC): %s\n" "$start_time"
	printf "\tRequested end time (UTC): %s\n" "$end_time"
	printf "\tRequested output time zone: \"%s\" - Ruby format\n" "$TIME_ZONE"
fi

if [ $SKIP_RPT_GEN == "false" ]; then
	# Generate all three reports: Unix, Windows and Other 
	#os_list="unix"
	os_list="unix windows dba other"
	for os in $os_list 
	do
		$report_home"/"$ruby_script "$start_time" "$end_time" $DEBUG $RECOVERY $os "$TIME_ZONE"
		if [ $? -ne 0 ]; then
			printf "There was an error in the Ruby script "$ruby_script" - exiting\n"
			exit 1
		fi
	done
fi

temp=`echo $TIME_ZONE | tr '/\ ' '___' | tr -d '()<>:"?*&' | sed -e 's/__/_/g'` 
regex='_[0-9]{2}-[0-9]{2}-[0-9]{4}_[0-9]{4}_to_[0-9]{2}-[0-9]{2}-[0-9]{4}_[0-9]{4}_'$temp'\.xls$'
if [ $RECOVERY == "true" ]
then 
	unix_filename=`/bin/find  $report_home -maxdepth 1 | /bin/egrep '^.+unix_alerts_with_recovery'$regex`
	windows_filename=`/bin/find  $report_home -maxdepth 1 | /bin/egrep '^.+windows_alerts_with_recovery'$regex`
	dba_filename=`/bin/find  $report_home -maxdepth 1 | /bin/egrep '^.+dba_alerts_with_recovery'$regex`
	other_filename=`/bin/find  $report_home -maxdepth 1 | /bin/egrep '^.+other_alerts_with_recovery'$regex`
else
	unix_filename=`/bin/find  $report_home -maxdepth 1 | /bin/egrep '^.+unix_alerts'$regex`
	windows_filename=`/bin/find  $report_home -maxdepth 1 | /bin/egrep '^.+windows'$regex`
	dba_filename=`/bin/find  $report_home -maxdepth 1 | /bin/egrep '^.+dba_alerts'$regex`
	other_filename=`/bin/find  $report_home -maxdepth 1 | /bin/egrep '^.+other_alerts'$regex`
fi

if [ $DEBUG == "true" ]; then
	echo Searching for:
	if [ $RECOVERY == "true" ]
	then 
		echo '^.+unix_alerts_with_recovery'$regex
		echo '^.+windows_alerts_with_recovery'$regex
		echo '^.+dba_alerts_with_recovery'$regex
		echo '^.+other_alerts_with_recovery'$regex
	else
		echo '^.+unix_alerts'$regex
		echo '^.+windows'$regex
		echo '^.+dba_alerts'$regex
		echo '^.+other_alerts'$regex
	fi
	temparr=(`ls *.xls`)
	printf '%s\n' "${temparr[@]}"
	if [ -f "$unix_filename" ]
	then
		echo Unix report $unix_filename created
	else
		echo No Unix report $unix_filename created
	fi
	if [ -f "$windows_filename" ]
	then
		echo Windows report $windows_filename created
	else
		echo No Windows report $windows_filename created
	fi
	if [ -f "$dba_filename" ]
	then
		echo DBA report $dba_filename created
	else
		echo No DBA report $dba_filename created
	fi
	if [ -f "$other_filename" ]
	then
		echo Other report $other_filename created
	else
		echo No Other $other_filename report created
	fi
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
if [ -n "$windows_filename" ]
then
	MANAGER_MAIL_CMD+=" -a "$windows_filename
fi
if [ -n "$dba_filename" ]
then
	MANAGER_MAIL_CMD+=" -a "$dba_filename
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
			echo cat $BODY \| $mutt_path -s "Unix Duty Pager Alerts Report" -a $unix_filename -- $recipient >> $log_file
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
			echo cat $BODY \| $mutt_path -s "Windows Duty Pager Alerts Report" -a $windows_filename -- $recipient >> $log_file 
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
			echo cat $BODY \| $mutt_path -s "DBA Duty Pager Alerts Report" -a $dba_filename -- $recipient >> $log_file 
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
			echo cat $BODY \| $mutt_path -s "Other Duty Pager Alerts Report" -a $other_filename -- $recipient >> $log_file 
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
	if [ ! -d $report_home"/reports/" ]; then
		mkdir $report_home"/reports/"
	fi
	mv $report_home"/"*.xls $report_home"/reports/"
fi

# Send the European Linux team report
# Set the time zone for output
TIME_ZONE="Europe/Berlin"

if [ $DEBUG == "true" ]; then
	system_tz=`cat /etc/sysconfig/clock | sed 's/^ZONE="\(.*\)"/\1/'` 
	printf "Values requested in BASH script:\n"
	if [ $CRON_JOB == "true" ]; then
		printf "\tRun in cronjob mode setting report period automatically\n"
	else
		printf "\tRun in non-cronjob mode\n"
	fi
	printf "\tSystem time zone: \"%s\" - Linux format\n" "$system_tz"
	printf "\tSystem local time: %s\n" "`date`"
	printf "\tRequested start time (UTC): %s\n" "$start_time"
	printf "\tRequested end time (UTC): %s\n" "$end_time"
	printf "\tRequested output time zone: \"%s\" - Ruby format\n" "$TIME_ZONE"
fi

if [ $SKIP_RPT_GEN == "false" ]; then
	# Generate just the unix report 
	os="unix"
	$report_home"/"$ruby_script "$start_time" "$end_time" $DEBUG $RECOVERY $os "$TIME_ZONE"
	if [ $? -ne 0 ]; then
		printf "There was an error in the Ruby script "$ruby_script" - exiting\n"
		exit 1
	fi
fi

temp=`echo $TIME_ZONE | tr '/\ ' '___' | tr -d '()<>:"?*&' | sed -e 's/__/_/g'` 
regex='_[0-9]{2}-[0-9]{2}-[0-9]{4}_[0-9]{4}_to_[0-9]{2}-[0-9]{2}-[0-9]{4}_[0-9]{4}_'$temp'\.xls$'
if [ $RECOVERY == "true" ]
then 
	unix_filename=`/bin/find  $report_home -maxdepth 1 | /bin/egrep '^.+unix_alerts_with_recovery'$regex`
else
	unix_filename=`/bin/find  $report_home -maxdepth 1 | /bin/egrep '^.+unix_alerts'$regex`
fi

if [ $DEBUG == "true" ]; then
	if [ -f "$unix_filename" ]
	then
		echo CET Unix report $unix_filename created
	else
		echo No CET Unix report $unix_filename created
	fi
fi

if [ -n "$unix_filename" ]
then
	if [ $DEBUG == "true" ]
	then
		printf "\nSending the CET Linux report\n"
	fi
	BODY="linux_team_body"$BODY_SUFFIX"_cet.txt"
	while read recipient 
	do
		if [ -z "`echo $recipient | egrep '^.*#'`" ]; then
			if [ $DEBUG == "true" ]; then
				echo cat $BODY \| $mutt_path -s "Unix Duty Pager Alerts Report" -a $unix_filename -- $recipient
			fi
			echo cat $BODY \| $mutt_path -s "Unix Duty Pager Alerts Report" -a $unix_filename -- $recipient >> $log_file
			cat $BODY | $mutt_path -s "Unix Duty Pager Alerts Report" -a $unix_filename -- $recipient
		fi
	done < $LINUX_TEAM_LIST_CET
fi

# Archive the reports
if [ $DEBUG == "false" ] || [ $FORCE_DELIVER == "true" ]; then
	if [ ! -d $report_home"/reports/" ]; then
		mkdir $report_home"/reports/"
	fi
	mv $report_home"/"*.xls $report_home"/reports/"
fi

# Send the India Linux team report
# Set the time zone for output
TIME_ZONE="Asia/Kolkata"

if [ $DEBUG == "true" ]; then
	system_tz=`cat /etc/sysconfig/clock | sed 's/^ZONE="\(.*\)"/\1/'` 
	printf "Values requested in BASH script:\n"
	if [ $CRON_JOB == "true" ]; then
		printf "\tRun in cronjob mode setting report period automatically\n"
	else
		printf "\tRun in non-cronjob mode\n"
	fi
	printf "\tSystem time zone: \"%s\" - Linux format\n" "$system_tz"
	printf "\tSystem local time: %s\n" "`date`"
	printf "\tRequested start time (UTC): %s\n" "$start_time"
	printf "\tRequested end time (UTC): %s\n" "$end_time"
	printf "\tRequested output time zone: \"%s\" - Ruby format\n" "$TIME_ZONE"
fi

if [ $SKIP_RPT_GEN == "false" ]; then
	# Generate just the unix report 
	os="unix"
	$report_home"/"$ruby_script "$start_time" "$end_time" $DEBUG $RECOVERY $os "$TIME_ZONE"
	if [ $? -ne 0 ]; then
		printf "There was an error in the Ruby script "$ruby_script" - exiting\n"
		exit 1
	fi
fi

temp=`echo $TIME_ZONE | tr '/\ ' '___' | tr -d '()<>:"?*&' | sed -e 's/__/_/g'` 
regex='_[0-9]{2}-[0-9]{2}-[0-9]{4}_[0-9]{4}_to_[0-9]{2}-[0-9]{2}-[0-9]{4}_[0-9]{4}_'$temp'\.xls$'
if [ $RECOVERY == "true" ]
then 
	unix_filename=`/bin/find  $report_home -maxdepth 1 | /bin/egrep '^.+unix_alerts_with_recovery'$regex`
else
	unix_filename=`/bin/find  $report_home -maxdepth 1 | /bin/egrep '^.+unix_alerts'$regex`
fi

if [ $DEBUG == "true" ]; then
	if [ -f "$unix_filename" ]
	then
		echo IST Unix report $unix_filename created
	else
		echo No IST Unix report $unix_filename created
	fi
fi

if [ -n "$unix_filename" ]
then
	if [ $DEBUG == "true" ]
	then
		printf "\nSending the IST Linux report\n"
	fi
	BODY="linux_team_body"$BODY_SUFFIX"_ist.txt"
	while read recipient 
	do
		if [ -z "`echo $recipient | egrep '^.*#'`" ]; then
			if [ $DEBUG == "true" ]; then
				echo cat $BODY \| $mutt_path -s "Unix Duty Pager Alerts Report" -a $unix_filename -- $recipient
			fi
			echo cat $BODY \| $mutt_path -s "Unix Duty Pager Alerts Report" -a $unix_filename -- $recipient >> $log_file
			cat $BODY | $mutt_path -s "Unix Duty Pager Alerts Report" -a $unix_filename -- $recipient
		fi
	done < $LINUX_TEAM_LIST_IST
fi

# Archive the reports
if [ $DEBUG == "false" ] || [ $FORCE_DELIVER == "true" ]; then
	if [ ! -d $report_home"/reports/" ]; then
		mkdir $report_home"/reports/"
	fi
	mv $report_home"/"*.xls $report_home"/reports/"
fi
