#!/bin/env ruby
# 20140927 djohnson
# 20150113 djohnson Added logic for Windows and other alerts
# 20150603 djohnson Combined Windows with recovery to standard report, added service and status columns
#	per John Rouillard's request

# Program arguments:
# 1st start date and time in "MM/DD/YYYY HH:MM" military time format. e.g. "06/11/2015 13:20" 
# 2nd end date and time in "MM/DD/YYYY HH:MM" military time format.
# 3rd cron job: true or false
# 4th debug mode: true or false
# 5th report O/S selector: unix, windows dba, or other

require 'rubygems'
require 'spreadsheet'
require 'date'
require 'mysql'
require 'json'
require 'active_support/all'
require_relative 'Notification'
require_relative 'functions'

if ARGV.length != 5
	puts "You submitted "+ARGV.length.to_s+" arguments."
	puts "This program requires five arguments: start time, end time, debug flag, recovery flag, and O/S"
	puts "     Ex. ruby alerts-report-new.rb \'06/11/2015 10:00\' \'06/18/2015 09:59\' false true Unix" 
	puts "The start and end date/time must be enclosed by quotes!"
	exit 0
end 

if ARGV[2].downcase == "true"
	debug=true
else
	debug=false
end

report_destination="/usr/local/nagios-management-reports"
verbose=false

# Convert to same DateTime class in the UTC time zone as in Nagios database 
utc_offset="-04:00" # Assume time input by user is EST

arr=ARGV[0].split('/')
month=arr[0].to_i
date=arr[1].to_i
year=arr[2].split[0].to_i
time=arr[2].split[1].to_i
hour=arr[2].split[1].split(':')[0].to_i
minute=arr[2].split[1].split(':')[1].to_i
start_time=DateTime.new(year,month,date,hour,minute,0,utc_offset).utc

arr=ARGV[1].split('/')
month=arr[0].to_i
date=arr[1].to_i
year=arr[2].split[0].to_i
time=arr[2].split[1].to_i
hour=arr[2].split[1].split(':')[0].to_i
minute=arr[2].split[1].split(':')[1].to_i
end_time=DateTime.new(year,month,date,hour,minute,59,utc_offset).utc

if ARGV[3] =="true"
	print_recovery=true
else
	print_recovery=false
end

os_selector = ARGV[4].dup.downcase
if ! (os_selector == "unix" || os_selector == "windows" || os_selector == "dba" || os_selector == "other")
	puts "You must choose a report os_selector for the 3rd argument: Unix, Windows, DBA or Other" 
	exit(1)
end

if debug
	puts
	puts "Start date, time and UTC offset: "+start_time.in_time_zone('Eastern Time (US & Canada)').strftime("%m/%d/%Y %H:%M EST")
	puts "End date, time, and UTC offset: "+end_time.in_time_zone('Eastern Time (US & Canada)').strftime("%m/%d/%Y %H:%M EST")
	if debug
		puts "Debug mode is on"
	else
		puts "Debug mode is off"
	end
	puts "Recovery record will be printed"
	puts "OS is "+os_selector.upcase
	puts "Report from "+start_time.in_time_zone('Eastern Time (US & Canada)').strftime("%m/%d/%Y %H:%M")+\
" to "+end_time.in_time_zone('Eastern Time (US & Canada)').strftime("%m/%d/%Y %H:%M")+" EST" 
	puts "Nagio Alerts: Source MySQL Database on Host \"monitor-global-10\"\n" 
end

Spreadsheet.client_encoding = 'UTF-8'
book = Spreadsheet::Workbook.new
sheet1 = book.create_worksheet :name => 'Alerts'
date_format = Spreadsheet::Format.new :number_format => 'DD.MM.YYYY'
NCOLS=8
UCFACT=0.5
bold_blue=Spreadsheet::Format.new :color => :blue,
                                 :weight => :bold,
                                 :size => 12
bold_black=Spreadsheet::Format.new :color => :black,
                                 :weight => :bold,
                                 :size => 10
right_justify = Spreadsheet::Format.new :horizontal_align => :right
centre_justify = Spreadsheet::Format.new :horizontal_align => :centre

sheet1.column(5).default_format=centre_justify
sheet1.column(6).default_format=centre_justify
sheet1.column(7).default_format=centre_justify
sheet1.row(0).default_format=bold_blue
sheet1.row(3).default_format=bold_black
sheet1.row(4).default_format=bold_black
sheet1.row(9).default_format=right_justify
sheet1.row(10).default_format=bold_black
sheet1.row(11).default_format=bold_black
sheet1.row(12).default_format=bold_black

# Define strings
daystr="     Day"
nightstr="     Night"
wkenddaystr="     Weekend Day"
wkendnightstr="     Weekend Night"

# Start adding rows to spreadsheet
if os_selector == "dba"
	temp=os_selector.upcase
	sheet1.row(0).push temp+" Duty Pager Alerts" 
else
	temp=os_selector[0].upcase+os_selector[1..-1]
	sheet1.row(0).push temp+" Duty Pager Alerts" 
end
sheet1.row(1).push "For Period from "+start_time.in_time_zone('Eastern Time (US & Canada)').strftime("%m/%d/%Y %H:%M")+\
" to "+end_time.in_time_zone('Eastern Time (US & Canada)').strftime("%m/%d/%Y %H:%M")+" EST" 
sheet1.row(2).push
sheet1.row(3).push "Summary" 
sheet1.row(4).push "","Alerts" 
sheet1.row(5).push "",daystr 
sheet1.row(6).push "",nightstr 
sheet1.row(7).push "",wkenddaystr 
sheet1.row(8).push "",wkendnightstr 
sheet1.row(9).push "","","===" 
sheet1.row(10).push "","Total"


sheet1.row(11)[7]=" Actionable"
sheet1.update_row 12,"Date","Host","Service","Status","Description","   Night"," Weekend","   (Yes/No)"
col_width_char=Array.new(NCOLS,0)
col_width_char[5]="   Night".length + UCFACT * count_upper("   Night") 	
col_width_char[6]=" Weekend".length + UCFACT * count_upper(" Weekend")	
col_width_char[7]="   (Yes/No)".length + UCFACT * count_upper("   (Yes/No)")	
UTC_to_EST_offset=-18000
i=13
incident_cnt=0
is_daytime_cnt=0
is_sleep_period_cnt=0
is_daytime_weekend_cnt=0
is_sleep_period_weekend_cnt=0
prev_host=""
prev_service=""
prev_recovery_host=""
prev_recovery_service=""

# Open Nagios database
con = Mysql.new '<host_name>', '<user_name>', '', '<database>', 3306

# obj1 = nagios_objects
# obj2 = nagios_objects

# Construct MySQL SELECT statement
where_clause=" WHERE nagios_notifications.start_time >= '"+start_time.to_s.gsub!('+00:00','\'').gsub!('T',' ')
where_clause+=" AND nagios_notifications.end_time <= '"+end_time.to_s.gsub!('+00:00','\'').gsub!('T',' ')
if debug
	puts "SQL \'WHERE\' clause: "+where_clause
end
rs=con.query 'SELECT obj1.objecttype_id as objecttype_id, obj1.name1 AS host_name, obj1.name2 AS service_description, obj2.name1 AS contact_name, obj3.name1 AS notification_command, nagios_contactnotifications.contactnotification_id, nagios_contactnotifications.contact_object_id, nagios_contactnotificationmethods.command_object_id, nagios_contactnotificationmethods.command_args, nagios_contactnotificationmethods.contactnotificationmethod_id, nagios_notifications.*, obj4.alias as contact_alias FROM nagios_notifications 
 
LEFT JOIN nagios_objects as obj1 ON nagios_notifications.object_id=obj1.object_id 
LEFT JOIN nagios_contactnotifications ON nagios_notifications.notification_id=nagios_contactnotifications.notification_id 
LEFT JOIN nagios_objects as obj2 ON nagios_contactnotifications.contact_object_id=obj2.object_id 
LEFT JOIN nagios_contactnotificationmethods ON nagios_contactnotifications.contactnotification_id=nagios_contactnotificationmethods.contactnotification_id
LEFT JOIN nagios_objects as obj3 ON nagios_contactnotificationmethods.command_object_id=obj3.object_id
LEFT JOIN nagios_contacts as obj4 ON nagios_contactnotifications.contact_object_id=obj4.contact_object_id'+where_clause

#puts JSON.dump rs.fetch_row
#puts JSON.dump rs.fetch_hash
#puts object_type(rs) 
#puts rs.inspect
# Loop through records nrec=0
nrec=0
rs.each do |objecttype_id,host_name,service_description,contact_name,notification_command,contactnotification_id,contact_object_id,command_object_id,command_args,contactnotificationmethod_id,notification_id,instance_id,notification_type,notification_reason,object_id,start_time,start_time_usec,end_time,end_time_usec,state,output,long_output,escalated,contactsnotified,contact_alias|

	begin
		nrec=nrec+1
		#printf "No. of records: %d\n",nrec
		notification=Notification.new(objecttype_id,host_name,service_description,contact_name,notification_command,contactnotification_id,contact_object_id,command_object_id,command_args,contactnotificationmethod_id,notification_id,instance_id,notification_type,notification_reason,object_id,start_time,start_time_usec,end_time,end_time_usec,state,output,long_output,escalated,contactsnotified,contact_alias)		
		
		# Type conversion
		objecttype_id=objecttype_id.to_i	
		contactnotification_id=contactnotification_id.to_i
		contact_object_id=contact_object_id.to_i
		command_object_id=command_object_id.to_i
		contactnotificationmethod_id=contactnotificationmethod_id.to_i
		notification_id=notification_id.to_i
		instance_id=instance_id.to_i
		notification_type=notification_type.to_i
		notification_reason=notification_reason.to_i
		object_id=object_id.to_i
		start_time_usec=start_time_usec.to_i
		end_time_usec=end_time_usec.to_i
		state=state.to_i
		escalated=escalated.to_i
		contactsnotified=contactsnotified.to_i

		# Date conversion
		dt_est=DateTime.iso8601(start_time.sub(/ /,'T')+"+00:00") - 4.0/24.0; 
		# Input to DateTime constructor is in iso8601 format and converted from UTC to EST.
		# Example: 2015-06-12T09:17:37+00:00 (EST would have appendix -04:00, Nagios use UTC)
		dtstr=dt_est.strftime("%m/%d/%Y %H:%M")

		is_custom_notification_record=false
		is_recovery_record=false
		is_sleep_period=false
		is_weekend=false
		record_selector = false

		# Determine if current record is a custom notification record
		if (long_output =~ / \(OK\)/)
			is_custom_notification_record=true
		else
			is_custom_notification_record=false
		end

		# Apparently, Nagios status codes returned on exit by a plugin and database state codes are different
		# or we are SMS paging on warnings that we consider to be critical

	    # Nagios Plugin Exit Codes

		#	Exit Code	Status
		#	0	OK
		#	1	WARNING
		#	2	CRITICAL
		#	3	UNKNOWN

		if debug
			if state == 0
				status="OK: "+state.to_s
				is_recovery_record=true
			elsif state == 1
				status="WARNING: "+state.to_s
			elsif state == 2
				status="CRITICAL: "+state.to_s
			else
				status="UNKNOWN: "+state.to_s 
			end
		else
			if state == 0
				status="OK"
				is_recovery_record=true
			elsif state == 1 || state == 2
				status="CRITICAL"
			else
				status="UNKNOWN: "+state.to_s 
			end
		end

		if notification_command =~ /notify-host/
			service="HOST DOWN"
		elsif notification_command =~ /notify-service/
			service=service_description
		else
			service="UNKNOWN"
		end	

		# Terminate description field if too long - can still be accessed by clicking on cell if desired
		sheet1[i,5]=" "

		# Determine if alert occured during sleep interval 9:00 p.m. till 7:00 a.m. the next morning
		dttmpstr=dt_est.strftime("%m/%d/%Y 00:00")
		dttmp=DateTime.strptime(dttmpstr, "%m/%d/%Y") 
		previous_day_sleep_start=dttmp.to_time.to_i-10800
		previous_day_sleep_end=previous_day_sleep_start+36000
		epoch_datetime=dt_est.to_time.to_i
		sleep_start=dttmp.to_time.to_i+75600 
		sleep_end=sleep_start+36000

		if (epoch_datetime >= previous_day_sleep_start && epoch_datetime <= previous_day_sleep_end) ||
			(epoch_datetime >= sleep_start && epoch_datetime <= sleep_end)
			is_sleep_period=true
		else
			is_sleep_period=false
		end

		# Determine if weekend
		if dt_est.wday == 0 || dt_est.wday == 6
			is_weekend=true
		else
			is_weekend=false
		end

		if verbose && debug
			printf "edt: %d pdss: %d pdse: %d ss: %d se: %d\n",epoch_datetime,previous_day_sleep_start,previous_day_sleep_end,sleep_start,sleep_end
		end

		# Determine record_selector value
		# We want roughly a count of one for each failure event as opposed to each alert.	
		# There can be many pages for a single failure event. Usually
		# there at least three: failure, acknowlegement and recovery.
		# Just print pager alerts, not Nagios email notifications
		if notification_command =~ /notify-host-by-sms/ || notification_command =~ /notify-service-by-sms/
			# Select records based on O/S
			if os_selector == "unix"
				if contact_alias !~ /WINDOWS/i && contact_alias =~ /UNIX/i && contact_alias !~ /DBA/i
					record_selector = true
				end
			elsif  os_selector == "windows"
				if contact_alias =~ /WINDOWS/i && contact_alias !~ /UNIX/i && contact_alias !~ /DBA/i
					record_selector = true
				end
			elsif os_selector == "dba"
				if contact_alias !~ /WINDOWS/i && contact_alias !~ /UNIX/i && contact_alias =~ /DBA/i  
					record_selector = true
				end
			elsif os_selector == "other"
				if contact_alias !~ /WINDOWS/i && contact_alias !~ /UNIX/i && contact_alias !~ /DBA/i  
					record_selector = true
				end
			else
				if contact_alias =~ /WINDOWS/i && contact_alias =~ /UNIX/i
					puts "Record indicates system is both Windows and Unix O/S" 
				else
					puts "Record selection logic is broken" 
				end
				exit(1)
			end
		end

		if record_selector == true

			if os_selector == "unix" && contact_name != "unix-droid"
				puts "OS is Unix, but contact name is not 'unix-droid': "+contact_name
			end

			# Filter out repeated alerts
			if !(host_name == prev_host && service == prev_service) && !is_recovery_record && !is_custom_notification_record
				incident_cnt+=1
				if is_sleep_period && is_weekend
					is_sleep_period_weekend_cnt+=1
				elsif is_sleep_period && !is_weekend
					is_sleep_period_cnt+=1
				elsif !is_sleep_period && is_weekend
					is_daytime_weekend_cnt+=1
				elsif !is_sleep_period && !is_weekend
					is_daytime_cnt+=1
				end
				
				# Print row
				col_width_char[0]=dtstr.length + UCFACT * count_upper(dtstr) > col_width_char[0] ? dtstr.length + UCFACT * count_upper(dtstr) : col_width_char[0] 	
				col_width_char[1]=host_name.length + UCFACT * count_upper(host_name) > col_width_char[1] ? host_name.length + UCFACT * count_upper(host_name) : col_width_char[1]	
				col_width_char[2]=service.length + UCFACT * count_upper(service) > col_width_char[2] ? service.length + UCFACT * count_upper(service) : col_width_char[2]	
				col_width_char[3]=status.length + UCFACT * count_upper(status) > col_width_char[3] ? status.length + UCFACT * count_upper(status) : col_width_char[3]	
				col_width_char[4]=long_output.strip.length + UCFACT * count_upper(long_output.strip) > col_width_char[4] ? long_output.strip.length + UCFACT * count_upper(long_output.strip) : col_width_char[4]	
				sheet1.update_row i,dtstr,host_name,service,status,long_output.strip
				if debug
					#puts
					#notification.typed_dump;	
					#printf("Row: %d\t%s\t%s\t%s\t%d\t%s\t%s\t%s\t%s\t%d\n",i,dtstr,host_name,service,incident_cnt,is_recovery_record,long_output,status,is_sleep_period,dt_est.wday)
				end

				# Print if night
				if is_sleep_period == true
					sheet1[i,5]="*"
					if verbose && debug
						printf "*Night*\n"
					end
				else
					if verbose && debug
						printf "*Day*\n"
					end
				end

				# Print if weekend
				if is_weekend == true
					sheet1[i,6]="*"
					if verbose && debug
						printf "*Weekend*\n"
					end
				else
					if verbose && debug
						printf "*Weekday*\n"
					end
				end

				i+=1
				prev_host=host_name
				prev_service=service
			end

			# Print recovery record if recovery version of report
			if print_recovery && !(host_name == prev_recovery_host && service == prev_recovery_service) && is_recovery_record
				col_width_char[0]=dtstr.length + UCFACT * count_upper(dtstr) > col_width_char[0] ? dtstr.length + UCFACT * count_upper(dtstr) : col_width_char[0] 	
				col_width_char[1]=host_name.length + UCFACT * count_upper(host_name) > col_width_char[1] ? host_name.length + UCFACT * count_upper(host_name) : col_width_char[1]	
				col_width_char[2]=service.length + UCFACT * count_upper(service) > col_width_char[2] ? service.length + UCFACT * count_upper(service) : col_width_char[2]	
				col_width_char[3]=status.length + UCFACT * count_upper(status) > col_width_char[3] ? status.length + UCFACT * count_upper(status) : col_width_char[3]	
				col_width_char[4]=long_output.strip.length + UCFACT * count_upper(long_output.strip) > col_width_char[4] ? long_output.strip.length + UCFACT * count_upper(long_output.strip) : col_width_char[4]	
				sheet1.update_row i,dtstr,host_name,service,status,long_output.strip
				if debug
					puts
					notification.typed_dump;	
					printf("Row rec: %d\t%s\t%s\t%s\t%d\t%s\t%s\t%s\t%s\t%d\n",i,dtstr,host_name,service,incident_cnt,is_recovery_record,status,long_output,is_sleep_period,dt_est.wday)
				end

				# Print if night
				if is_sleep_period == true
					sheet1[i,5]="*"
					if verbose && debug
						printf "*Night*\n"
					end
				else
					if verbose && debug
						printf "*Day*\n"
					end
				end

				# Print if weekend
				if is_weekend == true
					sheet1[i,6]="*"
					if verbose && debug
						printf "*Weekend*\n"
					end
				else
					if verbose && debug
						printf "*Weekday*\n"
					end
				end

				i+=1
				prev_recovery_host=host_name
				prev_recovery_service=service
			end

			sheet1.column(0).width=col_width_char[0]
			sheet1.column(1).width=col_width_char[1] < wkendnightstr.length + UCFACT * count_upper(wkendnightstr) ? wkendnightstr.length  + UCFACT * count_upper(wkendnightstr) : col_width_char[1]
			sheet1.column(2).width=col_width_char[2]
			sheet1.column(3).width=col_width_char[3]
			sheet1.column(4).width=col_width_char[4] > 100 ? 100 : col_width_char[4]
			sheet1.column(5).width=col_width_char[5]
			sheet1.column(6).width=col_width_char[6] + 2
			sheet1.column(7).width=col_width_char[7]
		end
			
	rescue TypeError
			$stderr.print "TypeError for record no: " + nrec.to_s + "\n"
			notification.dump;	
	end

end
# End of record loop

if (is_sleep_period_weekend_cnt + is_sleep_period_cnt + is_daytime_weekend_cnt + is_daytime_cnt) != incident_cnt
	puts "Sum of incident classifications does not equal the sum of incidents"
end

if debug
	for i in 0..NCOLS-1
		printf "No of characters in col: %d=%d\n",i,col_width_char[i]
	end
	puts "\nIncident Classification"
	printf "Daytime count: %d\n",is_daytime_cnt
	printf "Sleep period count: %d\n",is_sleep_period_cnt
	printf "Daytime weekend count: %d\n",is_daytime_weekend_cnt
	printf "Sleep period weekend count: %d\n",is_sleep_period_weekend_cnt
	printf "Total: %d\n",incident_cnt
end
sheet1[5,2]=is_daytime_cnt
sheet1[6,2]=is_sleep_period_cnt
sheet1[7,2]=is_daytime_weekend_cnt
sheet1[8,2]=is_sleep_period_weekend_cnt
sheet1[10,2]=incident_cnt

st=start_time.in_time_zone('Eastern Time (US & Canada)').strftime("%m-%d-%Y_%H:%M")
et=end_time.in_time_zone('Eastern Time (US & Canada)').strftime("%m-%d-%Y_%H:%M")
if print_recovery
	spreadsheet_file=report_destination+"/"+os_selector+"_alerts_with_recovery_"+st+"_to_"+et+"_EST.xls"
else
	spreadsheet_file=report_destination+"/"+os_selector+"_alerts_"+st+"_to_"+et+"_EST.xls"
end
book.write spreadsheet_file 
if debug
	puts "Wrote out file "+spreadsheet_file 
end
exit(0)
