# How to set up:
# $ bundle install --path vendor/bundle
# $ bundle exec ruby bot.rb

require 'rubygems'
require 'cinch'
require 'yaml'

class ConfigLoader
  include Cinch::Plugin
  
  match 'reload_config'
  
  def execute(m)
    log "Reloading configuration - Triggered by #{m.user.nick}"
    ConfigLoader.load
    
    m.reply "#{m.user.nick}: Konfiguration wurde geladen"
  end
  
  def self.load
    $config = YAML.load open(File.dirname(__FILE__) + '/config.yml').read
  end
  
end

require_relative 'plugin_loader'
ConfigLoader.load

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