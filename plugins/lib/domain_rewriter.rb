class DomainRewriter
  
  attr_accessor :pattern, :target, :datatype, :formatter
  
  DEFAULT_HASH = {
    'datatype' => :html
  }
  
  def initialize(pattern, target, datatype, formatter)
    @pattern = /#{pattern}/i
    @target = target
    @datatype = datatype.to_sym
    @formatter = (formatter.empty? ? nil : formatter)
    
    raise "Unknown rewriter datatype #{datatype}" unless [ :html, :json, :plain ].include? @datatype
  end
  
  def self.from_hash(descriptor)
    h = DEFAULT_HASH.merge descriptor
    DomainRewriter.new h.fetch('pattern'), h.fetch('target'), h.fetch('datatype'), h.fetch('formatter')
  end
  
  def self.many_from_array(array)
    result = array.map{|descr| DomainRewriter.from_hash descr }
    
    def result.check(url)
      DomainRewriter.check_all self, url
    end
    
    return result
  end
  
  def check(url)
    return nil unless url.match @pattern
    
    return { url: url.gsub(@pattern, @target), datatype: @datatype, formatter: @formatter }
  end
  
  def self.check_all(rewriters, url)
    descriptor = rewriters.map{|r| r.check url }.reject(&:nil?).first
    return descriptor if descriptor
    
    # Fallback
    return { url: url, datatype: :html }
  end
  
end