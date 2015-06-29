#!/bin/env ruby
# 20140927 djohnson
# 20150113 djohnson Added logic for Windows and other alerts
# 20150603 djohnson Combined Windows with recovery to standard report, added service and status columns
#	per John Rouillard's request

# Program arguments:
# 1st date in MM/DD/YYYY format 
# 2nd debug mode: true or false
# 3rd recovery mode: true or false
# 4th report O/S selector: unix, windows dba, or other

require 'rubygems'
require 'spreadsheet'
require 'date'
require 'json'

def count_upper(instr)
	ncount=0
	for i in 0..instr.length-1
		if /[[:upper:]]/.match(instr[i].chr)
			ncount+=1
		end
	end
	return ncount
end

Spreadsheet.client_encoding = 'UTF-8'
book = Spreadsheet::Workbook.new
sheet1 = book.create_worksheet :name => 'Alerts'
date_format = Spreadsheet::Format.new :number_format => 'DD.MM.YYYY'
NCOLS=8
UCFACT=0.5

if ARGV.length == 0 
	puts "You must pass the beginning date of the report into the program: \"DD/MM/YYYY\""
	exit(1)
end

if ARGV[1] =="true"
	# If cronjob run on Friday 
	cronjob=true 
	period_start_date=DateTime.strptime(ARGV[0], "%m/%d/%Y")-8
	period_end_date=DateTime.strptime(ARGV[0], "%m/%d/%Y")-2
else
	# If on demand run on any day
	cronjob=false
	period_start_date=DateTime.strptime(ARGV[0], "%m/%d/%Y")
	period_end_date=DateTime.strptime(ARGV[0], "%m/%d/%Y")+6
end

if ARGV[2] =="true"
	debug=true
	puts "Period start date: "+period_start_date.strftime("%m/%d/%Y")
	puts "Period end date: "+period_end_date.strftime("%m/%d/%Y")
else
	debug=false
end
verbose=false

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

# Friday's log has thursday's data
log_date=period_start_date+1
if debug
	puts "Report from "+period_start_date.strftime("%m/%d/%Y")+" till "+(period_end_date).strftime("%m/%d/%Y") 
	puts "Nagio Alerts: Source \"var/nagios.log\" on \"monitor-global-10\"\n" 
end
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
sheet1.row(1).push "Week of "+period_start_date.strftime("%m/%d/%Y") 
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
for j in 1..7
	# "combined" log named used for transition week logs Nagios Core -> Nagios XI
	#filename = "nagios-"+(log_date).strftime("%m-%d-%Y")+"-00.combined.log" 
	filename = "nagios-"+(log_date).strftime("%m-%d-%Y")+"-00.log" 
	if debug
		puts "Reading file: "+filename
	end

	# File I/O takes place in this block
	begin
		hostname=`hostname`.chop.gsub(/.mathworks.com/, '')
		if (hostname == "sysdev-00-ls")
			archive_dir="/usr/local/nagios/var/archives"
		elsif (hostname == "monitor-00-ah")
			archive_dir="/local/nagios/global/var/archives"
		elsif (hostname == "monitor-global-10")
			archive_dir="/usr/local/nagios/var/archives"
		end
		f = File.open(archive_dir+"/"+filename, "r")

		f.each_line do |line|
			is_custom_notification_record=false
			is_recovery_record=false
			is_sleep_period=false
			is_weekend=false
			record_selector = false

			# Determine if current record is a custom notification record
			if (line =~ / \(OK\)/)
				is_custom_notification_record=true
			else
				is_custom_notification_record=false
			end

			# Determine if current record is a recovery record
			if (line =~ / OK / || line =~ /;OK/ || line =~ /OK;/)
				is_recovery_record=true
			else
				is_recovery_record=false
			end

			fields=line.split(';');
			temp=fields[0].split(' ');
			date=temp[0]
			date=date[1..-2]
			date=date.to_i+UTC_to_EST_offset
			# Time.at().to_datetime converts Unix Epoch time into a SQL-standard DATETIME object
			# strftime() converts a Time object into a formatted string
			datetime=Time.at(date).to_datetime
			dtstr=datetime.strftime("%m/%d/%Y %H:%M")

			host=fields[1]
			if line =~ /notify-host-by-sms/
				service="HOST DOWN"
				status="CRITICAL"
			elsif line =~ /notify-service-by-sms/
				service=fields[2]
				status=fields[3]
			else
				service="ERROR"
				status="ERROR"
			end	

			# If recovery record, no matter status returned by Nagios, print "OK"
			if is_recovery_record
				status="OK"
			end

			msg=fields[4..-1]
			if msg != nil
				msg=msg.join(" ")
				#puts "**************** Mystery field: "+msg
				msg.slice! "notify-host-by-sms"
				msg.slice! "notify-service-by-sms"
				#puts "**************** line: "+line
				#puts "**************** Mystery field after slice: "+msg
				msg.gsub! "\n", ""
			end

			# Terminate description field if too long - can still be accessed by clicking on cell if desired
			sheet1[i,5]=" "

			# Determine if alert occured during sleep interval 9:00 p.m. till 7:00 a.m. the next morning
			dttmpstr=datetime.strftime("%m/%d/%Y 00:00")
			dttmp=DateTime.strptime(dttmpstr, "%m/%d/%Y") 
			previous_day_sleep_start=dttmp.to_time.to_i-10800
			previous_day_sleep_end=previous_day_sleep_start+36000
			epoch_datetime=datetime.to_time.to_i
			sleep_start=dttmp.to_time.to_i+75600 
			sleep_end=sleep_start+36000

			if (epoch_datetime >= previous_day_sleep_start && epoch_datetime <= previous_day_sleep_end) ||
				(epoch_datetime >= sleep_start && epoch_datetime <= sleep_end)
				is_sleep_period=true
			else
				is_sleep_period=false
			end

			# Determine if weekend
			if datetime.wday == 0 || datetime.wday == 6
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
			if line !~ /ACKNOWLEDGEMENT/
				# Just print pager alerts, not Nagios email notifications
				if line =~ /notify-host-by-sms/ || line =~ /notify-service-by-sms/
					# Select records based on O/S
					if os_selector == "unix"
						if line.upcase !~ /WINDOWS/ && line =~ /unix-droid/ && line !~ /beep-DBAs/
							record_selector = true
						end
					elsif  os_selector == "windows"
						if line.upcase =~ /WINDOWS/ && line !~ /unix-droid/ && line !~ /beep-DBAs/
							record_selector = true
						end
					elsif os_selector == "dba"
						if line.upcase !~ /WINDOWS/ && line !~ /unix-droid/ && line =~ /beep-DBAs/  
							record_selector = true
						end
					elsif os_selector == "other"
						if line.upcase !~ /WINDOWS/ && line !~ /unix-droid/ && line !~ /beep-DBAs/  
							record_selector = true
						end
					else
						if line.upcase =~ /WINDOWS/ && line =~ /unix-droid/
							puts "Record indicates system is both Windows and Unix O/S" 
						else
							puts "Record selection logic is broken" 
						end
						exit(1)
					end
				end
			end

			if record_selector == true

				# Filter out repeated alerts
				if !(host == prev_host && service == prev_service) && !is_recovery_record && !is_custom_notification_record
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
					
					# Handle nil fields
					if dtstr == nil
						dtstr=""
					end
					if host == nil
						host=""
					end
					if service == nil
						service=""
					end
					if status == nil
						status=""
					end
					if msg == nil
						msg=""
					end
 
					# Print row
					col_width_char[0]=dtstr.length + UCFACT * count_upper(dtstr) > col_width_char[0] ? dtstr.length + UCFACT * count_upper(dtstr) : col_width_char[0] 	
					col_width_char[1]=host.length + UCFACT * count_upper(host) > col_width_char[1] ? host.length + UCFACT * count_upper(host) : col_width_char[1]	
					col_width_char[2]=service.length + UCFACT * count_upper(service) > col_width_char[2] ? service.length + UCFACT * count_upper(service) : col_width_char[2]	
					col_width_char[3]=status.length + UCFACT * count_upper(status) > col_width_char[3] ? status.length + UCFACT * count_upper(status) : col_width_char[3]	
					col_width_char[4]=msg.strip.length + UCFACT * count_upper(msg.strip) > col_width_char[4] ? msg.strip.length + UCFACT * count_upper(msg.strip) : col_width_char[4]	
					sheet1.update_row i,dtstr,host,service,status,msg.strip
					if debug
						printf("Row: %d\t%s\n",i,line.delete("\n"))
						printf("Row: %d\t%s\t%s\t%s\t%d\t%s\t%s\t%s\t%s\t%d\n",i,dtstr,host,service,incident_cnt,is_recovery_record,msg,status,is_sleep_period,datetime.wday)
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
					prev_host=host
					prev_service=service
				end

				# Print recovery record if recovery version of report
				if print_recovery && !(host == prev_recovery_host && service == prev_recovery_service) && is_recovery_record
					col_width_char[0]=dtstr.length + UCFACT * count_upper(dtstr) > col_width_char[0] ? dtstr.length + UCFACT * count_upper(dtstr) : col_width_char[0] 	
					col_width_char[1]=host.length + UCFACT * count_upper(host) > col_width_char[1] ? host.length + UCFACT * count_upper(host) : col_width_char[1]	
					col_width_char[2]=service.length + UCFACT * count_upper(service) > col_width_char[2] ? service.length + UCFACT * count_upper(service) : col_width_char[2]	
					col_width_char[3]=status.length + UCFACT * count_upper(status) > col_width_char[3] ? status.length + UCFACT * count_upper(status) : col_width_char[3]	
					col_width_char[4]=msg.strip.length + UCFACT * count_upper(msg.strip) > col_width_char[4] ? msg.strip.length + UCFACT * count_upper(msg.strip) : col_width_char[4]	
					sheet1.update_row i,dtstr,host,service,status,msg.strip
					if debug && 	
						printf("Row rec: %d\t%s\n",i,line.delete("\n"))
						printf("Row rec: %d\t%s\t%s\t%s\t%d\t%s\t%s\t%s\t%s\t%d\n",i,dtstr,host,service,incident_cnt,is_recovery_record,status,msg,is_sleep_period,datetime.wday)
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
					prev_recovery_host=host
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
				
		# End of for each line loop
		end
		f.close

	rescue Exception => e
	 	puts "\tAn error occurred: #{$!}"	
		puts e.backtrace
		puts "\tConfirm that you requested a reporting period that contains logs for all seven days of the report."
		puts "Period start date: "+period_start_date.strftime("%m/%d/%Y")
		puts "Period end date: "+period_end_date.strftime("%m/%d/%Y")
		exit(1);
	# End of file I/O trap
	end
	log_date+=1

# End of log file for each loop
end

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

if print_recovery
	book.write os_selector+"_alerts_with_recovery_"+(period_start_date).strftime("%m-%d")+"_to_"+(period_start_date+6).strftime("%m-%d")+".xls"
else
	book.write os_selector+"_alerts_"+(period_start_date).strftime("%m-%d")+"_to_"+(period_start_date+6).strftime("%m-%d")+".xls"
end
exit(0)
