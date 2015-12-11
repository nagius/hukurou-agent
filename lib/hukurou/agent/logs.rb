
module Hukurou
	module Agent
		class CustomFormatter < Logger::Formatter
			DateFormat = "%Y-%m-%d %H:%M:%S %z"

			def initialize()
			end

			def call(severity, time, progname, msg)
				"[#{time.strftime(DateFormat)}] #{severity} #{msg2str(msg)}\n"
			end
		end
	end
end

# vim: ts=4:sw=4:ai:noet

