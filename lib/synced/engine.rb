module Synced
  class Engine < ::Rails::Engine
    isolate_namespace Synced

    config.generators do |g|
      g.test_framework :rspec
    end
  end
end
