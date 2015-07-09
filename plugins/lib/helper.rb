module Helper
  
  def get_matchers_for_url(url)
    host = URI(url).host
    (host.count('.') + 2).times.map{|i| host.split(/(?<=\.)/)[i..-1].join}
  end
  
end