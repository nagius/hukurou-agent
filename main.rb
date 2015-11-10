#!/usr/bin/env ruby

require 'socket'
require 'eventmachine'
require 'em-http-request'
require 'json'
require 'yaml'
require 'optparse'
require 'logger'
require 'active_support/all'
require_relative 'em-twistedlike'
require_relative 'workers'
require_relative 'logs'


def load_config
	# Default configuration
	config_file = "config.yml"
	$CFG = {
		:url => "http://127.0.0.1:9292/api",
		:debug => false
	}

	# Read CLI options
	options = {}
	OptionParser.new do |opts|
		opts.banner = "Usage: #{$0} [options]"

		opts.on("-d", "--debug", "Turn on debug output") do |d|
			options[:debug] = d
		end

		opts.on("-c", "--config-file FILENAME", "Specify a config file", String) do |file|
			config_file = file
		end

		opts.on("-u", "--url URL", "Url of server's API", String) do |url|
			options[:url] = url
		end
	end.parse!

	# Load configuration file
	begin
		$CFG.merge!(YAML.load_file(config_file))
	rescue StandardError => e
		abort "Cannot load config file #{config_file}: #{e}"
	end

	# Override configuration file with command line options
	$CFG.merge!(options)
end

def get_json(url)
	d = EM::HttpRequest.new(url).get
	d.add_errback { |http|
		raise http.error
	}
	d.add_callback { |http|
		raise http.response_header.http_reason unless http.response_header.status == 200

		JSON.parse(http.response).deep_symbolize_keys
	}
	
	return d
end

def get_config(workers)
	d = get_json("#{$CFG[:url]}/v1/device/#{Socket.gethostname}/config")
	d.add_callback { |data|
		workers.reload(data)
	}
    d.add_errback { |e|
		$log.error "Can't get config from server: #{e}"
		EM.stop
    }
end


load_config

# Setup logger 
# Logging to a file and handle rotation is a bad habit. Instead, stream to STDOUT and let the system manage logs.
$log = Logger.new STDOUT
$log.formatter = CustomFormatter.new 
$log.level = $CFG[:debug] ? Logger::DEBUG : Logger::INFO

# Start main loop
workers = Workers.new
EM.run {
	$log.info "Starting agent..."
	get_config(workers)

	Signal.trap("INT") { EM.stop }
	Signal.trap("TERM") { EM.stop }
	Signal.trap("HUP") {
		# Use add_timer to avoid trap conflict with Ruby 2.0
		# https://github.com/eventmachine/eventmachine/issues/418
		EM.add_timer(0) {
			$log.info "Reloading config from server..."
			get_config(workers)
		}
	}
}


# vim: ts=4:sw=4:ai:noet
