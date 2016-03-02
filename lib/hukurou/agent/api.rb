# Hukurou - Another monitoring tool, the modern way.
# Copyleft 2015 - Nicolas AGIUS <nicolas.agius@lps-it.fr>
#
################################################################################
#
# This file is part of Hukurou.
#
# Hukurou is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
################################################################################

require 'socket'
require 'json'
require 'em-http-request'

module Hukurou
	module Agent
		module API
			
			# Asynchronous helper to get symbolized JSON output form an HTTP GET call
			#
			# @param url [String] The URL to get
			# @return [Deferrable] Will raise a HTTPError wrapped in a Failure in case of HTTP error
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

			# Load the device configuration from the Core API and reload local workers
			#
			# @param [Workers] The Workers object to reload
			# @return [Deferred] Fired when the Workers has been reloaded
			def self.get_config(workers)
				d = get_json("#{Config[:url]}/config/#{Socket.gethostname}")
				d.add_callback { |data|
					workers.reload(data[:services])
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
