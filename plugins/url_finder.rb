require 'htmlentities'
require 'net/http'
require 'nokogiri'
require 'cinch'
require 'json'
require 'uri'

require_relative 'lib/domain_rewriter'
require_relative 'lib/blacklist'
require_relative 'lib/helper'

class UrlFinder
  include Cinch::Plugin
  include Helper
  
  MAX_REDIRECTS = 3
  
  CLIENT_HEADERS = {
    'User-Agent' => "Maido WebCrawler (Moe Moe Kyun!)",
    'Accept' => "text/html, text/*, application/json"
  }
  
  listen_to :channel
  match /ogp ([^ ]+)/, method: :ogp_lookup
  
  def initialize(*args)
    super
    
    @formatters = eval open('formatters.rb').read
    @rewriters = DomainRewriter.many_from_array($config['domain']['rewrite'])
  end
  
  def do_get_request(url, datatype)
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
        
        break unless type =~ /#{datatype}/i
        
        response.read_body{|body| data << body }
      end
    end
    
    return [ data, type, code, location ]
  end
  
  def download_url(url, datatype)
    data = ''
    type = nil
    code = 300
    location = nil
    
    #
    counter = 0
    while (code / 100) == 3 && counter < MAX_REDIRECTS
      data, type, code, location = do_get_request URI(url), datatype
      counter = counter + 1
      
      url = location if location
    end
    
    
    #File.open("download.log", "w"){|f| f.write data } ## DEBUG
    
    return [ data, type, code ]
  end
  
  def get_formatter(matchers)
    matchers.map{|name| @formatters[name] }.reject(&:nil?).first
  end
  
  def render_formatter(descriptor, response, original_url)
    args = []
    
    # 
    case descriptor[:datatype]
    when :html
      parser = Nokogiri::HTML response
      args = [ read_ogp_data(parser), read_title(parser, original_url), parser ]
      
    when :json
      args = [ JSON.parse(response) ]
      
    when :text
      args = [ ]
      
    end
    
    # Append standard arguments
    args << response << descriptor << original_url
    
    # 
    formatter = @formatters[descriptor[:formatter]]
    formatter = get_formatter get_matchers_for_url descriptor[:url] if formatter.nil?
    rendered = nil
    
    begin
      rendered = formatter.call *args
    rescue StandardError => err
      error "Failed to format URL #{original_url.to_s}"
      exception err
      rendered = "Einen Fehler {#{err.class.name}: #{err.message} @ #{err.backtrace.first}}"
    end
    
    rendered = 'Seite ohne Titel' if rendered.nil?
    cleaned = rendered.gsub(/[\r\n]/, ' ').scrub(' ').strip
    return nil if cleaned.empty?
    return cleaned
  end
  
  def rewrite_url(url)
    descriptor = @rewriters.check url
    log "Descriptor for #{url}: #{descriptor.map{|k,v| "[" + k.to_s + " => " + v.to_s + "]"}.join(', ')}"
    return descriptor
  end
  
  def handle_url(url)
    response = nil
    
    descriptor = rewrite_url url
    
    begin
      response, type, code = download_url(descriptor[:url], descriptor[:datatype].to_sym)
      
      if code != 200
        return "Eine #{code} Seite"
      end
      
      type = 'Unbekannt' if type.nil? || type.empty?
      return nil unless type =~ /#{descriptor[:datatype]}/i
    rescue SocketError => err
      return "Eine nicht-existente Domain"
    rescue RuntimeError => err
      log "Exception caught: #{err.message} at #{err.backtrace.first}"
      return "Ein Programmfehler"
    end
    
    # 
    return render_formatter descriptor, response, url
  end
  
  def read_ogp_data(parser)
    coder = HTMLEntities.new
    og = parser.css('meta[property^="og:"]').map{ |meta| [ meta['property'].slice(3, 100), coder.decode(meta['content']) ] }.to_h
    log "OGP Data: " + og.map{ |k,v| "#{k}: #{v}" }.join(', ')
    
    return nil if og.empty?
    return og
  end
  
  def read_title(parser, url)
    tag = parser.css('title')[0]
    return nil if tag.nil?
    
    matchers = get_matchers_for_url url # Try to remove trailing service name with other garbage characters before it
    matchers << matchers[-2].split('.').first
    return tag.children[0].to_s.gsub /[^a-z0-9.]*#{matchers.map{|m| Regexp.escape m}.join '|'}$/i, ''
  end
  
  def find_urls(message)
    # Port part in url_rx intentionally left out. Only ping "public" pages!
    url_rx = /(https?:\/\/([a-z0-9_.-]+)\/[a-z0-9%._\/?&+=#-]*)/i
    ignore_domain_rx = /^(?:localhost|[0-9.]+)$/ # Don't ping localhost or plain IP addresses
    
    message
      .scan(url_rx) # Find URLs
      .reject{|pair| pair.last.match ignore_domain_rx} # Ignore hardcoded domains
      .reject{|pair| Blacklist.instance.blacklisted? pair.last } # Ignore blacklist
      .map(&:first) # Prettify
  end
  
  def listen(m)
    urls = find_urls m.message
    return if urls.empty?
    
    log "Found urls #{urls.join ','} in message"
    
    responses = urls.map{ |url| handle_url url }.reject(&:nil?)
    log "Titles: #{responses.join ', '}"
    
    m.reply "#{m.user.nick} präsentiert Ihnen heute: #{responses.join ', '}" unless responses.empty?
  end
  
  def ogp_lookup(m, url)
    log "Pinging #{url}"
    
    descriptor = rewrite_url url
    m.reply "#{m.user.nick}: Eingegebene URL wurde umgeschrieben -> #{descriptor[:url]}" if descriptor[:url] != url
    
    # Load
    response, type, code = download_url(descriptor[:url], :html)
    return m.reply "#{m.user.nick}: Das gab einen Fehler #{code}" if code != 200
    
    # Parse
    parser = Nokogiri::HTML response
    og = read_ogp_data(parser)
    title = read_title(parser, url)
    
    og_str = og.empty? ? '<Keine>' : og.map{|k, v| "#{k}: '#{v}'"}.join(', ')
    
    # 
    begin
      formatted = render_formatter(descriptor, response, url)
    rescue RuntimeError => err
      formatted = "Fehler #{err.class}: #{err.message} @ #{err.backtrace.first}"
    end
    
    # 
    m.reply "#{m.user.nick}: Seitentitel ist „#{title || '<Leer>'}“, OGP Daten: #{og_str}"
    m.reply "#{m.user.nick}: Formatiert mit \"#{descriptor[:formatter]}\": #{formatted}"
    
  end
  
end