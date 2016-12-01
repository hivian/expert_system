def shutdown
	puts "Shutting down gracefully..."
	sleep 1
	exit(false)
end

Signal.trap("INT") { 
  shutdown 
  exit(false)
}

Signal.trap("TERM") {
  shutdown
  exit(false)
}

define_method :clearAll do | factArray, rulesToCode, factStatement, rules |
	rules.clear
	rulesToCode.clear
	factStatement.clear
	('A'..'Z').each do |c|
		factArray.store(c, false)
	end
end

define_method :runExpression do |rulesToCode, index|
	begin
		eval "if #{rulesToCode[index][0]}\n#{rulesToCode[index][2]} end"
		if rulesToCode[index][1] == "<=>"
			rulesToCode[index][0].gsub!(/\==/, '=')
			rulesToCode[index][2].gsub!(/\=/, '==')
			eval "if #{rulesToCode[index][2]}\n#{rulesToCode[index][0]} end"
		end	
	rescue Exception => e
		puts "Rule #{index + 1}: syntax error"
		return false
	end
	return true
end

define_method :engine do |rulesToCode|
	i = 1
	rulesToCode.each_with_index do |line, index|
		rulesToCode.each_with_index do |line, index|
			if index < i
				if runExpression(rulesToCode, index) == false
					return false
				end 
			else
				break
			end
		end
		if i == rulesToCode.size && i > 1
			rulesToCode.each_with_index do |line, index|
				runExpression(rulesToCode, index)
			end
		end
		i += 1
	end
	return true
end

define_method :runEngine do |filename, factArray, rulesToCode, factStatement, rules|
	clearAll(factArray, rulesToCode, factStatement, rules)
	file = File.open(filename)
	read = file.read
	read.gsub!(/#.*$/, '')
	read.split('').each do |c|
		if !c.match(/[A-Z()!?+^|=<>\s*\t*\n+]/)
			puts "Unknow character present"
			file.close
			return
		end
	end
	if !read.match(/^=[A-Z]*\s*$/)
		puts "Facts: syntax error"
		file.close
		return
	elsif read.match(/^\?\s*$/)
		puts "Queries: none"
		file.close
		return
	elsif !read.match(/^\?[A-Z]+\s*$/)
		puts "Queries: syntax error"
		file.close
		return
	end
	if facts = read.match(/^=[A-Z]+\s*$/).to_s
		('A'..'Z').each do |c|
			if facts.include? c
				factArray[c] = true
			end
		end
	else
		facts = ""
	end
	if !facts.empty?
		factStatement = facts.gsub!(/[\=\n]/, '').split('').each { |fact| factStatement << fact }
	else
		factStatement = ""
	end
	read.each_line do |line|
		if line.match(/^\(?!?[A-Z]/)
			rules.push(line)
		end
	end
	if rules.any?
		duplicates = rules.each_with_object([]) { |e, a| a << e if rules.count(e) > 1 }
		if duplicates.any?
			puts "Rules: duplicates expression"
			clearAll(factArray, rulesToCode, factStatement, rules)
			file.close
			return 
		end
		rulesError = false
		rules.each_with_index do |line, index|
			if !line.match(/^\(?!?[A-Z]\s+([+|^]|=>|<=>)\s+\(?!?[A-Z]\)?/) or line.match(/[A-Z]\s*[A-Z]/) \
			or line.match(/([+|^]|=>|<=>)\s*([+|^]|=>|<=>)/)
				puts "Rule #{index + 1}: syntax error"
				clearAll(factArray, rulesToCode, factStatement, rules)
				file.close
				return
			else
				expression = line.gsub!(/^/, ' ')
				expression = line.split(/(=>|<=>)/)
				if expression.to_s.count("(") != expression.to_s.count(")")
					puts "Rule #{index + 1}: parentheses not properly closed"
					clearAll(factArray, rulesToCode, factStatement, rules)
					rulesError = true
					break
				elsif expression[2].match(/[\||^]/)
					puts "Rule #{index + 1}: ambiguous ruleset \"" + expression[1] + " " + expression[2].strip + "\""
					clearAll(factArray, rulesToCode, factStatement, rules)
					rulesError = true
					break
				else
					if expression[0].match(/\([A-Z]/)
						expression[0].gsub!(/([A-Z])/, 'factArray["\1"] == true')
					else
						expression[0].gsub!(/([^!])([A-Z])/, ' factArray["\2"] == true')
					end
					expression[0].gsub!(/(!)([A-Z])/, 'factArray["\2"] == false')
					if expression[2].match(/\([A-Z]/)
						expression[2].gsub!(/([A-Z])/, 'factArray["\1"] == true')
					else
						expression[2].gsub!(/([^!])([A-Z])/, ' factArray["\2"] = true')
					end
					expression[2].gsub!(/(!)([A-Z])/, 'factArray["\2"] = false')
					expression.map { |e| e.gsub!("+", "&&") }
					expression.map { |e| e.gsub!("|", "||") }
					expression.map do |e|
						if e.match(/\(?factArray\["[A-Z]"\] == (true|false)\s+\^\s+factArray\["[A-Z]"\] == (true|false)\)?/)
							e.gsub!(/(factArray\["[A-Z]"\] == (true|false))/, '(\1)')
						end
					end
					rulesToCode << expression
				end
			end
		end
	end
	if !rulesError
		if engine(rulesToCode) == false
			clearAll(factArray, rulesToCode, factStatement, rules)
			return
		end
		if queries = read.match(/^\?[A-Z]+\s*$/).to_s
			puts queries.strip
			('A'..'Z').each do |c|
				if queries.include? c
					puts "#{c} = " + factArray[c].to_s
				end
			end
		end
	end
	file.close
	return
end

factArray = {}
	('A'..'Z').each do |c|
	factArray.store(c, false)
end
puts "\033[31mWelcome to this interactive Expert System."
puts "Type \"help\" to print a list of available commands."
puts "By default, all facts are false, and can only be made true"
puts "by the initial facts statement, or by application of a rule.\033[0m"
time = Time.now.getutc.strftime("%H:%M:%S")
print "\033[33m#{time} [No file loaded] >> \033[0m"
filename = ""
factStatement = []
rulesToCode = []
rules = []
noFile = true
while input = $stdin.gets
	input ||= ""
	input.chomp!
	args = input.split(' ')
	if input.match(/^quit\s*$/)
		shutdown
	elsif input.match(/^reset\s*$/)
		clearAll(factArray, rulesToCode, factStatement, rules)
		noFile = true
		puts "Cleared"
	elsif input.match(/^rules\s*$/)
		if rules.empty?
			puts "Rules: none"
		else
			rules.each do |rule|
				puts rule.strip
			end
		end
	elsif input.match(/^fact\s+[A-Za-z]+\s+=\s+(true|false)\s*$/)
		if args[3] == "true"
			args[1].split('').each do |letter|
				isFact = false
				factStatement.each do |fact|
					if fact == letter.upcase
						isFact = true
					end
				end
				if isFact == false
					factStatement << letter.upcase
				end
			end
		else
			args[1].split('').each do |letter|
				factStatement.each do |fact|
					if fact == letter.upcase
						factStatement.delete(fact)
					end
				end
			end
		end
		puts "Success"
	elsif input.match(/^save\s*$/)
		if rulesToCode.empty?
			puts "Rules: none"
		else
			('A'..'Z').each do |c|
				factArray.store(c, false)
			end
			factStatement.each do |fact|
				factArray.store(fact, true)
			end
			engine(rulesToCode)
			puts "Saved and reevaluated"
		end
	elsif input.match(/^facts\s*$/)
		factArray.each { |key, value| puts "#{key} = #{value}" }
	elsif input.match(/^facts:statement\s*$/)
		puts "=" + factStatement.join(',').gsub(',', '').chars.sort.join
	elsif input.match(/^query\s+[A-Za-z]+\s*$/)
		args[1].split('').each do |letter|
			puts letter.upcase + " = " + factArray[letter.upcase].to_s
		end
	elsif input.match(/^help\s*$/)
		puts "====================================== COMMANDS ======================================="
		puts "#                                                                                     #"
		puts "#    run   [file path]               : load a file and run it. Reset all facts        #"
		puts "#                                                                                     #"
		puts "#    fact  [letter] = [true/false]   : set the fact statement (not saved !)           #"
		puts "#    save                            : save the new facts and reevaluate the rules    #"
		puts "#    query [letters]                 : print the fact(s) corresponding                #"
		puts "#                                                                                     #"
		puts "#    rules                           : print all rules                                #"
		puts "#    facts                           : print all saved facts                          #"
		puts "#    facts:statement                 : print all facts statements                     #"
		puts "#    reset                           : reset all facts and rules                      #"
		puts "#    quit                            : exit the program                               #"
		puts "#                                                                                     #"
		puts "======================================================================================="
	elsif input.match(/^run\s+.+\s*$/)
		filename = args[1]
		if !File.file?(filename)
			puts filename + " is not a file."
		elsif !File.readable?(filename)
			puts filename + ": permission denied"
		elsif File.zero?(filename)
			puts filename + " is empty."
		else
			runEngine(filename, factArray, rulesToCode, factStatement, rules)
			if !rules.empty?
				noFile = false
			else
				noFile = true
			end
		end
	else
		puts "Unknow command"
	end
	time = Time.now.getutc.strftime("%H:%M:%S")
	print "\033[33m#{time} "
	if noFile == false
		print "[" + filename + "]"
	else
		print "[No file loaded]"
	end
	print " >> \033[0m"
end
