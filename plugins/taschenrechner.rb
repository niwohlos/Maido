require 'cinch'

class Taschenrechner
  include Cinch::Plugin
  
  match /calc (.*)/
  
  def execute(m, expression)
    log "Calculating: #{expression}"
    response = nil
    
    begin
      sanity_check expression
      response = run_expression(expression).to_s
    rescue RuntimeError => err
      response = "Willst du mich verarschen?"
      error "Faulty expression: #{expression}"
      exception err
    end
    
    m.reply "#{m.user.nick}: #{response}" if response
  end
  
  def run_expression(expression)
    eval "Kernel.include ::Math\n#{expression}"
  end
  
  def sanity_check(str)
    allowed_methods = Math.methods(false).map(&:to_s).join('|')
    allowed_terminals = '([ ()+*\/-])'
    allowed_digits = '[0-9](?:\.[0-9])|\.[0-9]'
    
    allowed = /\A#{[allowed_methods, allowed_terminals, allowed_digits].join('|')}\z/
    token = str.split(/([ ()+*\/-])/).map(&:strip).reject(&:empty?)
    
    token.each do |tok|
      raise "Illegal token '#{tok}'" unless tok =~ allowed
    end
    
  end
  
end