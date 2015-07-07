require 'cinch'

class PluginLoader
  include Cinch::Plugin
  
  match 'reload_plugins'
  
  def execute(m)
    log "Reloading plugins - Triggered by user"
    
    begin
      list = PluginLoader.load_all
    rescue StandardError => err
      log "Failed with #{err.name}"
      m.reply "Das gab einen #{err.name} bei #{err.backtrace.first}"
      raise err
    end
    
    # 
    bot.plugins.unregister_all
    bot.plugins.register_plugins list
    
    names = (list - [ PluginLoader ]).map{|klass| klass.name }
    m.reply "Neugeladene Plugins: #{names.join ', '}"
  end
  
  ###
  def self.load_all
    plugins = Dir.glob('plugins/*.rb').map do |file|
      puts "Loading plugin #{file}"
      raise "Failed to load plugin #{file}" unless load file
      
      base_name = file.match(/^.*\/([^\.]+)\.rb$/)[1]
      class_name = base_name.gsub(/(?:^|_)([a-z])/i){|m| m.slice(-1).upcase }
      
      raise "Plugin #{file} does not define class #{class_name} - Broken plugin!" unless Kernel.const_defined? class_name
      
      Kernel.const_get(class_name)
    end
    
    # Inject self
    return [ PluginLoader ] + plugins
  end
  
end