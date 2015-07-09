require_relative 'helper'
require 'singleton'
require 'yaml'

class Blacklist
  include Singleton
  include Helper
  
  DEFAULT_PATH = 'blacklist.yml'
  
  def initialize
    @file_path = DEFAULT_PATH
    reload
  end
  
  def reload
    begin
      @list = YAML.parse open(@file_path).read
      puts "Read blacklist form #{@file_path}"
    rescue Errno::ENOENT
      puts "Blacklist file #{@file_path} not found - Using empty blacklist"
      @list = []
    end
    
    puts "Blacklist has #{@list.length} entries"
  end
  
  def write
    File.open(@file_path, 'w'){|f| f.write YAML.dump @list}
  end
  
  def blacklisted?(url)
    matchers = get_matchers_for_url url
    return !matchers.map{|m| @list.include? m.downcase }.reject(&:!).empty?
  end
  
  def add(domain)
    domain = domain.downcase
    @list << domain unless @list.include? domain
  end
  
  def remove(domain)
    @list.delete domain.downcase
  end
  
  def length
    @list.length
  end
  
end