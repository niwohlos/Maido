# How to set up:
# $ bundle install --path vendor/bundle
# $ bundle exec ruby bot.rb

require 'rubygems'
require_relative 'plugin_loader'

# 
bot = Cinch::Bot.new do
  
  configure do |conf|
    conf.nick = 'Meido'
    conf.server = "irc.euirc.net"
    conf.channels = %w(#niwohlos)
    conf.plugins.plugins = PluginLoader.load_all
  end
  
end

bot.start