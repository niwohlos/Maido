def shorten(string, max = 60)
  return string if string.length < max
  return string.slice(0, max) + "…"
end

# Matches og['site_name'].downcase for the default matcher
ignore_description = [ :imgur, :voat ]
ignore_image = [ :reddit, :voat, :youtube, :facebook ]

# All formatters receive the following arguments
# (... , plain response body, formatter descriptor, original url)
# With ... depending on the rewriter type:
#  html (default): ... = OpenGraph data, HTML title, Nokogiri parser
#  json: ... = parsed JSON data
#  text: ... = <nothing>
{
  # Default matcher for HTML
  "" => Proc.new do |og, title|
    unless og.nil?
      site = og['site_name'].downcase.to_sym unless og['site_name'].nil?
      title = og['title']
      title << " [#{shorten og['description']}]" if og['description'] && !ignore_description.include?(site)
      title << " -> #{og['image']}" if og['image'] && !ignore_image.include?(site)
    end
    
    title
  end,
  
  # Note: "foo.bar.baz" will search for the matchers "foo.bar.baz", "bar.baz", "baz", "" (in this order)
  "youtube.com" => Proc.new{|og| og['title'] },
  
  "twitter.com" => Proc.new{|og| "#{og['title'].gsub(/ auf Twitter$/, '')}: #{og['description']}" },
  
  "reddit.com" => Proc.new do |og|
    description = ''
    if og['description']
      stripped = og['description'].gsub(/(?:\*\*|''|__)/, '').gsub(/\[([^\]]+)\]\([^)]*\)/, '\1')
      description = " [#{shorten stripped}]"
    end
    "#{og['title']}#{description}"
  end,
  
  # JSON formatters
  "4chan" => Proc.new do |json, response, descriptor, url|
    uri = URI(url)
    frag = uri.fragment
    board = uri.path.match(/^\/([^\/]+)\//)[1]
    
    post = json['posts'].first
    if !frag.nil? && !frag.empty? && frag.start_with?('p')
      no = frag[1..-1].to_i
      post = json['posts'].find(post){ |post| post['no'] == no }
    end
    
    suffix = ''
    suffix = " -> https://i.4cdn.org/#{board}/#{post['tim']}#{post['ext']}" if post['tim']
    
    content = HTMLEntities.new.decode post['com'].gsub('<br>', '  ').gsub(/<[^>]*>/, '')
    
    "“#{shorten(content, 120)}”#{suffix}"
  end
  
}
