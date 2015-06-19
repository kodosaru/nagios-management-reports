def count_upper(instr)
	ncount=0
	for i in 0..instr.length-1
		if /[[:upper:]]/.match(instr[i].chr)
			ncount+=1
		end
	end
	return ncount
end

def object_type(obj)
	if obj.is_a?(TrueClass)
		return "TrueClass"
	end
	if obj.is_a?(FalseClass)
		return "FalseClass"
	end
	if obj.is_a?(String)
		return "String"
	end
	if obj.is_a?(Fixnum)
		return "Fixnum"
	end
	if obj.is_a?(Float)
		return "Float"
	end
	if obj.is_a?(Bignum)
		return "Bignum"
	end
	if obj.is_a?(Symbol)
		return "Symbol"
	end
	if obj.is_a?(Hash)
		return "Hash"
	end
	if obj.is_a?(Object)
		print "Object: "
		if obj.is_a?(Notification)
			puts "Notification"
		end
		if obj.is_a?(Mysql::Result)
			puts "Mysql::Result"
		end
	end
end
