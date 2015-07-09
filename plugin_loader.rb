require 'cinch'

class PluginLoader
  include Cinch::Plugin
  
  CORE_PLUGINS = [ ConfigLoader, PluginLoader ]
  
  match 'reload_plugins'
  
  def execute(m)
    log "Reloading plugins - Triggered by #{m.user.nick}"
    
    begin
      list = PluginLoader.load_all
    rescue StandardError => err
      error "Failed with #{err.class.name}: #{err.message}"
      error "Backtrace:"
      error "#{err.backtrace.join("\n")}"
      m.reply "Das gab einen #{err.class.name} mit '#{err.message}' bei #{err.backtrace.first}"
      raise err
    end
    
    # 
    bot.plugins.unregister_all
    bot.plugins.register_plugins list
    
    names = (list - CORE_PLUGINS).map{|klass| klass.name }
    m.reply "Neugeladene Plugins: #{names.join ', '}"
  end
  
  ###
  def self.inject_hook(klass)
    klass.include HookMethods
    klass.class_eval{ hook :pre }
    return klass
  end
  
  def self.load_all
    plugins = Dir.glob('plugins/*.rb').map do |file|
      puts "Loading plugin #{file}"
      raise "Failed to load plugin #{file}" unless load file
      
      base_name = file.match(/^.*\/([^\.]+)\.rb$/)[1]
      class_name = base_name.gsub(/(?:^|_)([a-z])/i){|m| m.slice(-1).upcase }
      
      raise "Plugin #{file} does not define class #{class_name} - Broken plugin!" unless Kernel.const_defined? class_name
      
      self.inject_hook Kernel.const_get(class_name)
    end
    
    # Inject self
    return CORE_PLUGINS + plugins
  end
  
  private
  
  module HookMethods
    def hook(m)
      return !($config['ignored_nicks'].include? m.user.nick.downcase)
    end
  end
  
end