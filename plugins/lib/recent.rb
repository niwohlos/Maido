require 'thread'

class Recent
  
  RECENT_SECONDS = 1800 # 30 minutes
  CLEAN_INTERVAL_SECONDS = 60 # 1 minute
  
  def initialize
    @recent = {}
    
    @mutex = Mutex.new
    
    @clean_up_thread = Thread.new do
      loop do
        remove_old
        sleep CLEAN_INTERVAL_SECONDS
      end
    end
    
  end
  
  def remove_recent_urls(urls)
    @mutex.synchronize{ urls.reject{|url| @recent.values.include? url} }
  end
  
  def add_recent_urls(urls)
    urls.each{|url| add_recent_url url }
  end
  
  def add_recent_url(url)
    @mutex.synchronize do
      @recent.any?{|time, u| @recent.delete time if url == u }
      @recent[Time.now] = url
    end
  end
  
  def remove_old
    old = Time.now - RECENT_SECONDS
    @mutex.synchronize{ @recent = @recent.reject{|time, _| time < old } }
  end
  
end