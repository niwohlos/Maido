require 'cinch'

class Uhrzeit
  include Cinch::Plugin
  
  match "time"
  match "uhrzeit"
  
  def execute(m)
    m.reply "#{m.user.nick}: Hier ists grad #{Time.now.strftime '%H:%M:%S am %d.%m.%Y'}"
  end
  
end