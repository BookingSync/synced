module Synced
  class Engine < ::Rails::Engine
    isolate_namespace Synced

    config.generators do |g|
      g.test_framework :rspec
    end

    config.to_prepare do
      require "synced/engine/has_synced_data"
    end

    ActiveSupport.on_load :active_record do
      extend Synced::Engine::Model
    end
  end
end

require "synced/engine/model"
