
require 'yaml'
require 'optparse'
require 'singleton'

module Hukurou
	module Agent
		class Config
			include Singleton
			
			attr_reader :config

			def initialize
				# Default configuration file
				@config_file = "/etc/hukurou/agent/config.yml"

				# Default configuration
				@config = {
					:url => "http://127.0.0.1:1664",
					:debug => false,
					:timeout => 30
				}
			end

			def self.load
				instance.load_config
			end

			def self.[](key)
				instance.config[key]
			end

			def load_config
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
					@config.merge!(YAML.load_file(@config_file))
				rescue StandardError => e
					abort "Cannot load config file #{@config_file}: #{e}"
				end

				# Override configuration file with command line options
				@config.merge!(options)

				# Setup logger 
				# Logging to a file and handle rotation is a bad habit. Instead, stream to STDOUT and let the system manage logs.
				# http://www.mikeperham.com/2014/09/22/dont-daemonize-your-daemons/
				$log = Logger.new STDOUT
				$log.formatter = CustomFormatter.new 
				$log.level = @config[:debug] ? Logger::DEBUG : Logger::INFO
			end
		end
	end
end

# vim: ts=4:sw=4:ai:noet
