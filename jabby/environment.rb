require 'rubygems'
require 'bundler/setup'
require 'base64'
require 'json'
require 'celerity'
require 'mongoid'
require 'haml'
require 'redis'
require 'lib/name_gen/name_gen'
require 'sinatra' unless defined?(Sinatra)

configure do
  # mongoid config
  file_name = File.join(File.dirname(__FILE__), "config", "mongoid.yml")
  @mongoid_config = YAML.load(ERB.new(File.new(file_name).read).result)

  Mongoid.configure do |config|
    config.from_hash(@mongoid_config['production'])
  end

  # load models
  $LOAD_PATH.unshift("#{File.dirname(__FILE__)}/models")
  Dir.glob("#{File.dirname(__FILE__)}/models/*.rb") { |lib| require File.basename(lib, '.*') }

  REDIS = Redis.new(:host => '', :password => '')
end

