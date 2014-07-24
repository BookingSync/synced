require "synced/model"

module Synced
  class Engine < ::Rails::Engine
    isolate_namespace Synced

    config.generators do |g|
      g.test_framework :rspec
    end

    config.to_prepare do
      require "synced/has_synced_data"
    end

    ActiveSupport.on_load :active_record do
      extend Synced::Model
    end
  end
end
