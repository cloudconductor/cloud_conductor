require 'binding_of_caller'
require 'mixlib/log'

module CloudConductor
  class Logger
    extend Mixlib::Log

    class << self
      def init(*args)
        super(*args)
        self.level = Rails.application.config.log_level
        logger.formatter = proc do |severity, time, _progname, msg|
          format("[%s] %5s -- %s\n", time.iso8601(3), severity, msg)
        end
        logger
      end

      def debug_with_trace(progname = nil, &block)
        caller_class = binding.of_caller(1).eval('self.class')
        caller_method = caller.first.match(/in `(.*)'/)[1]
        line_number = caller.first.split(':')[1]
        progname = "(#{caller_class}.#{caller_method}:#{line_number}): #{progname}"
        _debug(progname, &block)
      end

      alias_method :_debug, :debug
      alias_method :debug, :debug_with_trace
    end
  end
end
