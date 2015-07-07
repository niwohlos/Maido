def shorten(string, max = 60)
  return string if string.length < max
  return string.slice(0, max) + "…"
end

{
  # Default matcher
  "" => -> (og, title, _) do
    unless og.nil?
      title = og['title']
      title << " [#{shorten og['description']}]" if og['description']
      title << " -> #{og['image']}" if og['image']
    end
    
    title
  end,
  
  # Note: "foo.bar.baz" will search for the matchers "foo.bar.baz", "bar.baz", "baz", "" (in this order)
  "youtube.com" => -> (og, _, _){ og['title'] },
  
  "twitter.com" => -> (og, _, _){ "#{og['title'].gsub(/ auf Twitter$/, '')}: #{og['description']}" }

}