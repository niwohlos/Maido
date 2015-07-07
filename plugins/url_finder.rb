require 'htmlentities'
require 'net/http'
require 'nokogiri'
require 'cinch'
require 'uri'

class UrlFinder
  include Cinch::Plugin
  
  MAX_REDIRECTS = 3
  
  CLIENT_HEADERS = {
    'User-Agent' => "Maido WebCrawler (Moe Moe Kyun!)",
    'Accept' => "text/html, text/*"
  }
  
  listen_to :channel
  
  def initialize(*args)
    super
    
    @formatters = eval open('formatters.rb').read
  end
  
  def is_html_mimetype(type)
    return (type =~ /\/html/i)
  end
  
  def do_get_request(url)
    data = ''
    type = nil
    code = 0
    location = nil
    
    options = {}
    if url.scheme == 'https'
      options = {
        use_ssl: true,
        verify_mode: OpenSSL::SSL::VERIFY_PEER
      }
    end
    
    # 
    path = '/'
    path = "#{url.path}#{!url.query.nil? ? '?' + url.query : ''}" unless url.path.empty?
    
    Net::HTTP.start url.host, url.port, options do |http|
      http.request_get(path) do |response|
        type = response['Content-Type']
        location = response['Location']
        code = response.code.to_i
        
        break unless is_html_mimetype type
        
        response.read_body{|body| data << body }
      end
    end
    
    return [ data, type, code, location ]
  end
  
  def download_url(url)
    data = ''
    type = nil
    code = 300
    location = nil
    
    #
    counter = 0
    while (code / 100) == 3 && counter < MAX_REDIRECTS
      data, type, code, location = do_get_request URI(url)
      counter = counter + 1
      
      url = location if location
    end
    
    
    #File.open("download.log", "w"){|f| f.write data } ## DEBUG
    
    return [ data, type, code ]
  end
  
  def get_matchers_for_url(url)
    host = URI(url).host
    (host.count('.') + 2).times.map{|i| host.split(/(?<=\.)/)[i..-1].join}
  end
  
  def get_formatter(matchers)
    matchers.map{|name| @formatters[name] }.reject(&:nil?).first
  end
  
  def render_title(url, parser)
    og = read_ogp_data(parser)
    title = read_title(parser)
    
    formatter = get_formatter get_matchers_for_url url
    rendered = nil
    
    begin
      rendered = formatter.call og, title, parser
    rescue StandardError => err
      error "Failed to format URL #{url.to_s}"
      exception err
    end
    
    rendered = 'Seite ohne Titel' if rendered.nil?
    return rendered
  end
  
  def handle_url(url)
    response = nil
    
    begin
      response, type, code = download_url(URI url)
      
      if code != 200
        return "Eine #{code} Seite"
      end
      
      type = 'Unbekannt' if type.nil? || type.empty?
      return "MIME-Typ #{type}" unless is_html_mimetype type
    rescue SocketError => err
      return "Eine nicht-existente Domain"
    rescue RuntimeError => err
      log "Exception caught: #{err.message} at #{err.backtrace.first}"
      return "Ein Programmfehler"
    end
    
    # 
    parser = Nokogiri::HTML response
    return render_title url, parser
  end
  
  def read_ogp_data(parser)
    coder = HTMLEntities.new
    og = parser.css('meta[property^="og:"]').map{ |meta| [ meta['property'].slice(3, 100), coder.decode(meta['content']) ] }.to_h
    log "OGP Data: " + og.map{ |k,v| "#{k}: #{v}" }.join(', ')
    
    return nil if og.empty?
    return og
  end
  
  def read_title(parser)
    tag = parser.css('title')[0]
    return tag[0].to_s if tag
    return nil
  end
  
  def listen(m)
    urls = URI.extract(m.message, %w(http https))
    
    return if urls.empty?
    
    log "Found urls #{urls.join ','} in message"
    
    responses = urls.map{ |url| handle_url url }
    log "Titles: #{responses.join ', '}"
    m.reply "#{m.user.nick} präsentiert Ihnen heute: #{responses.join ', '}"
  end
  
end