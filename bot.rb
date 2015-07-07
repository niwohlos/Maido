# How to set up:
# $ bundle install --path vendor/bundle
# $ bundle exec ruby bot.rb

require 'rubygems'
require_relative 'plugin_loader'
require 'yaml'

$config = YAML.load open(File.dirname(__FILE__) + '/config.yml').read

# 
bot = Cinch::Bot.new do
  
  configure do |conf|
    descr = $config['bot']
    conf.realname = descr['realname']
    conf.nick = descr['nick']
    conf.port = descr['port'].to_i if descr['port']
    conf.ssl = true if %w(true yes).include? descr['ssl']
    conf.server = descr['server']
    conf.channels = descr['channels']
    conf.plugins.plugins = PluginLoader.load_all
  end
  
end

bot.start