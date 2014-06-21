module Synced
  class Engine < ::Rails::Engine
    isolate_namespace Synced

    config.generators do |g|
      g.test_framework :rspec
    end

    config.to_prepare do
      require "synced/engine/lib/has_synced_data"
    end
  end
end
