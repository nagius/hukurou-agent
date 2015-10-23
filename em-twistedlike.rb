require 'active_support/all'

# http://twistedmatrix.com/documents/12.0.0/core/howto/defer.html

module EventMachine
	# Wrap the defer into a Deferrable with exception handling
	def self.defer_to_thread(&block)
		d=EM::DefaultDeferrable.new

		operation = proc {
			begin
				block.call
			rescue StandardError => e
				d.fail(e)
			end
		}

		EM.defer(operation, proc { |result| d.succeed(result) })

		return d
	end

	module Deferrable
		def add_callback(&block)
			add_callbacks(block, proc { |args| args })
		end

		def add_errback(&block)
			add_callbacks(proc { |args| args }, block)
		end

		def add_both(&block)
			add_callbacks(block, block)
		end

		def add_callbacks(success, error)
			def wrap_call(block)
				begin
					res = block.call(*@deferred_args)
					case res
					when StandardError
						raise res if @errbacks.blank?	# Raise exception if there is no errback to handle it
						fail(res)						# Call next errback if an exception has been returned
					else
						succeed(res)
					end
				rescue StandardError => e
					raise e if @errbacks.blank?			# Raise exception if there is no errback to handle it
					fail(e)
				end
			end

			if @deferred_status.nil? or @deferred_status == :unknown
				callback {
					@errbacks.pop unless @errbacks.nil?
					wrap_call(success)
				}
				errback {
					@callbacks.pop unless @callbacks.nil?
					wrap_call(error)
				}
			else
				# Run the corresponding block immediately if the Defer has already been fired
				block = @deferred_status == :succeeded ? success : error
				wrap_call(block)
			end
		end

		def chain_deferred(d)
			callback { |args| d.succeed(args) }
			errback  { |args| d.fail(args) }
			self
		end

	end

	class DefaultDeferrable
		def self.failed(*args)
			d = new
			d.fail(*args)
			return d
		end
	
		def self.succeeded(*args)
			d = new
			d.succeed(*args)
			return d
		end
	end
end

# vim: ts=4:sw=4:ai:noet
