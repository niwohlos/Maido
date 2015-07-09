require 'cinch'
require 'uri'

require_relative 'lib/blacklist'

class SperrlistenKontrolle
  include Cinch::Plugin
  
  match /blacklisted ([^ ]+)/, method: :blacklisted?
  match /blacklist ([^ ]+)/, method: :blacklist
  match /unblacklist ([^ ]+)/, method: :unblacklist
  
  def blacklisted?(m, url)
    url = "http://#{url}" unless URI(url).host
    
    infix = 'NICHT '
    infix = '' if Blacklist.instance.blacklisted? url
    m.reply "#{m.user.nick}: Diese Domain ist #{infix}auf der Sperrliste"
  end
  
  
  def blacklist(m, url)
    domain = (URI(url).host || url).downcase
    
    if Blacklist.instance.blacklisted? "http://#{domain}/"
      m.reply "#{m.user.nick}: #{domain} ist bereits auf der Sperrliste"
    else
      Blacklist.instance.add domain
      Blacklist.instance.write
      m.reply "#{m.user.nick}: #{domain} wurde gesperrt"
    end
    
  end
  
  def unblacklist(m, url)
    domain = (URI(url).host || url).downcase
    
    if Blacklist.instance.blacklisted? "http://#{domain}/"
      Blacklist.instance.remove domain
      Blacklist.instance.write
      m.reply "#{m.user.nick}: #{domain} wurde von der Sperrliste genommen"
    else
      m.reply "#{m.user.nick}: #{domain} ist nicht auf der Sperrliste"
    end
    
  end
  
end