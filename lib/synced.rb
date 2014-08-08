require "synced/rails"

module Synced
  # Default instrumenter which does nothing.
  module NoopInstrumenter
    def self.instrument(name, payload = {})
      yield payload if block_given?
    end
  end

  cattr_accessor :instrumenter
  self.instrumenter = NoopInstrumenter
end
