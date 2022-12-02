$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "synced/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "synced"
  s.version     = Synced::VERSION
  s.authors     = ["Sebastien Grosjean", "Mariusz Pietrzyk"]
  s.email       = ["dev@bookingsync.com"]
  s.homepage    = "https://github.com/BookingSync/synced"
  s.summary     = "Keep your BookingSync Application synced with BookingSync."
  s.description = "Keep your BookingSync Application synced with BookingSync."
  s.license     = "MIT"

  s.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  s.test_files = Dir["span/**/*"]

  s.add_dependency "rails", ">= 6"
  s.add_dependency "bookingsync-api", ">= 0.1.4"
  s.add_dependency "hashie"

  s.add_development_dependency "appraisal"
  s.add_development_dependency "sqlite3"
  s.add_development_dependency "rspec-rails"
  s.add_development_dependency "listen", "~> 2.7"
  s.add_development_dependency "guard-rspec"
  s.add_development_dependency "timecop"
  s.add_development_dependency "vcr"
  s.add_development_dependency "webmock"
  s.add_development_dependency "globalize", ">= 4.0.2"
  s.add_development_dependency "pry"
end
