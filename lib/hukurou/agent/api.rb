
require 'socket'
require 'json'

require 'em-http-request'

module Hukurou
	module Agent
		module API
			def self.get_json(url)
				d = EM::HttpRequest.new(url).get
				d.add_callback { |http|
					if http.response_header.status != 200
						raise HTTPError, http.response_header.http_reason + ": " + http.response
					end
						
					JSON.parse(http.response).deep_symbolize_keys
				}
				d.add_errback { |failure|
					if failure.value.instance_of? EM::HttpClient
						raise HTTPError, failure.value.error
					end
					failure	# Forward Failure down the errback chain
				}
				
				return d
			end

			def self.get_config(workers)
				d = get_json("#{$CFG[:url]}/device/#{Socket.gethostname}/config")
				d.add_callback { |data|
					workers.reload(data)
				}
				d.add_errback { |failure|
					$log.error "Failed to fetch config: #{failure}"
					EM.stop
				}

				return d
			end
		end
	end
end

class Hukurou::Agent::API::HTTPError < StandardError
end

# vim: ts=4:sw=4:ai:noet
