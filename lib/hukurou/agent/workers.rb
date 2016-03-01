
require 'socket'


module Hukurou
	module Agent

		# Taken from core/lib/database.rb
		module State
			OK = "OK"
			CRIT = "CRIT"
			WARN = "WARN"
			STALE = "STALE"
		end

		class Workers
			def initialize
				@localhost = Socket.gethostname
				@workers = Array.new
				@services = Hash.new
			end

			def reload(services)
				@services = services
				restart_workers()
			end

			def start_workers()
				$log.info "[WORKERS] Starting workers..."

				@services.each_pair do |service, conf|
					if not (conf.has_key?(:remote) and conf[:remote])
						@workers << EM::PeriodicTimer.new(conf[:interval]) do
							run_check(service, conf)
						end
					end
				end
			end

			def stop_workers()
				if  @workers.any?
					$log.info "[WORKERS] Stopping workers..."
					@workers.each { |worker|
						worker.cancel()
					}
					@workers.clear
				end
			end

			def restart_workers()
				stop_workers()
				start_workers()
			end

			# TODO: factorize with server ?
			def run_check(service, conf)
				$log.debug "[WORKERS] Checking #{service} with #{conf}..."

				d=EM.defer_to_thread {
					output = ::IO.popen(conf[:command], :err=>[:child, :out]) do |io| 
						begin
							Timeout.timeout(Config[:timeout]) { io.read }
						rescue Timeout::Error
							Process.kill 9, io.pid
							raise
						end
					end

					case $?.exitstatus
						when 0
							state = State::OK
						when 1
							state = State::WARN
						when 3
							state = State::STALE
						else
							state = State::CRIT
					end
					[state, output]
				}

				d.add_callback { |result|
					send_state(service, result[0], result[1])
				}

				d.add_errback { |e|
					message = "Failed to run #{conf[:command]}: #{e}"
					$log.debug "[WORKERS] #{message}"
					send_state(service, State::CRIT, message)
				}

				return d
			end

			def send_state(service, state, message)
				params = {:state => state, :message => message }
				$log.debug "[WORKERS] Sending check result to server: #{params}"

				d = EM::HttpRequest.new("#{Config[:url]}/states/#{@localhost}/#{service}").post(:body => params)
				d.add_callback { |http|
					if http.response_header.status == 201
						$log.debug "[WORKERS] Check result successfuly sent: #{params}"
					else
						raise "#{http.response}"    # Unexpected response code
					end
				}
				d.add_errback { |reason|
					if reason.value.instance_of? EM::HttpClient
						$log.error "[WORKERS] HTTP error: #{reason.value.error}"
					else
						$log.error "[WORKERS] Failed to sent status: #{reason.value}"
					end
				}

				return d
			end
		end
	end
end

# vim: ts=4:sw=4:ai:noet
