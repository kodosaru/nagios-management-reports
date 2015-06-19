class Notification
	def initialize(objecttype_id, host_name, service_description, contact_name, notification_command, contactnotification_id, contact_object_id, command_object_id, command_args, contactnotificationmethod_id, notification_id, instance_id, notification_type, notification_reason, object_id, start_time, start_time_usec, end_time, end_time_usec, state, output, long_output, escalated, contactsnotified, contact_alias)
		if objecttype_id == nil 
			@objecttype_id=-1
		else
			@objecttype_id=objecttype_id
		end
		if host_name == nil
			@host_name="nil"
		else
			@host_name=host_name
		end
		if service_description == nil
			@service_description="nil"
		else
			@service_description=service_description
		end
		if contact_name == nil
			@contact_name="nil"
		else	
			@contact_name=contact_name
		end
		if notification_command == nil
			@notification_command="nil"
		else
			@notification_command=notification_command
		end
		if contactnotification_id == nil 
			@contactnotification_id=-1
		else
			@contactnotification_id=contactnotificationmethod_id
		end
		if contact_object_id == nil 
			@contact_object_id=-1
		else
			@contact_object_id=contact_object_id
		end
		if command_object_id == nil
			@command_object_id=-1
		else
			@command_object_id=command_object_id
		end
		if command_args =
			@command_args="nil"
		else
			@command_args=command_args
		end
		if contactnotificationmethod_id == nil 
			@contactnotificationmethod_id=-1
		else
			@contactnotificationmethod_id=contactnotificationmethod_id
		end
		if notification_id == nil
			@notification_id=-1
		else
			@notification_id=notification_id
		end
		if instance_id == nil
			@instance_id=-1
		else
			@instance_id=instance_id
		end
		if notification_type == nil
			@notification_type=-1
		else
			@notification_type=notification_type
		end
		if notification_reason == nil
			@notification_reason=-1
		else
			@notification_reason=notification_reason
		end
		if object_id == nil
			@object_id=-1
		else
			@object_id=object_id
		end
		if start_time == nil
			@start_time="nil"
		else
			@start_time=start_time
		end
		if start_time_usec == 0
			@start_time_usec=-1
		else
			@start_time_usec=start_time_usec
		end
		if end_time == nil
			@end_time="nil"
		else
			@end_time=end_time
		end
		if end_time_usec == nil
			@end_time_usec=-1
		else
			@end_time_usec=end_time_usec
		end
		if state == nil
			@state=-1
		else
			@state=state
		end
		if output == nil
			@output="nil"
		else
			@output=output
		end
		if long_output == nil
			@long_output="nil"
		else
			@long_output=long_output
		end
		if escalated == nil
			@escalated=-1
		else
			@escalated=escalated
		end
		if contactsnotified == nil
			@contactsnotified="nil"
		else
			@contactsnotified=contactsnotified
		end
		if contact_alias == nil
			@contact_alias="nil"
		else
			@contact_alias=contact_alias
		end
	end

	def dump
		printf "objecttype_id: %s host_name: %s service_description: %s contact_name: %s notification_command: %s contactnotification_id: %s contact_object_id: %s command_object_id: %s command_args: %s contactnotificationmethod_id: %s notification_id: %s instance_id: %s notification_type: %s notification_reason: %s object_id: %s start_time: %s start_time_usec: %s end_time: %s end_time_usec: %s state: %s output: %s long_output: %s escalated: %s contactsnotified: %s contact_alias: %s\n", @objecttype_id, @host_name, @service_description, @contact_name, @notification_command, @contactnotification_id, @contact_object_id, @command_object_id, @command_args, @contactnotificationmethod_id, @notification_id, @instance_id, @notification_type, @notification_reason, @object_id, @start_time, @start_time_usec, @end_time, @end_time_usec, @state, @output, @long_output, @escalated, @contactsnotified, @contact_alias
	end

	def typed_dump
		printf "objecttype_id: %d host_name: %s service_description: %s contact_name: %s notification_command: %s contactnotification_id: %d contact_object_id: %d command_object_id: %d command_args: %s contactnotificationmethod_id: %d notification_id: %d instance_id: %d notification_type: %d notification_reason: %d object_id: %d start_time: %s start_time_usec: %d end_time: %s end_time_usec: %d state: %d output: %s long_output: %s escalated: %d contactsnotified: %d contact_alias: %s\n", @objecttype_id, @host_name, @service_description, @contact_name, @notification_command, @contactnotification_id, @contact_object_id, @command_object_id, @command_args, @contactnotificationmethod_id, @notification_id, @instance_id, @notification_type, @notification_reason, @object_id, @start_time, @start_time_usec, @end_time, @end_time_usec, @state, @output, @long_output, @escalated, @contactsnotified, @contact_alias
	end

end
