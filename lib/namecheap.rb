require 'rubygems'
require 'httparty'
require 'yaml'

class NilNamecheapResponse < Exception
end

class NamecheapResponse
  def initialize(response)
    @response = response
  end

  def status
    @response["ApiResponse"]["Status"] 
  end

  def message
    if @response["ApiResponse"]["Errors"].any?
      @response["ApiResponse"]["Errors"]["Error"]
    end
  end

  def items
    response = @response["ApiResponse"]["CommandResponse"]
    raise NilNamecheapResponse if response.nil?
    response.delete_if { |key, value| key == "Type" }
  end

end

class DomainCheck
  attr_accessor :domain, :available, :error, :description

  def initialize(item)
    @domain = item["Domain"]
    @available = (item["Available"] == "true" ? true : false)
    @error = item["ErrorNo"]
    @description = item["Description"]
  end
end

class LockCheck
  attr_accessor :domain, :status
  
  def initialize(item)
    @domain = item["Domain"]
    @status = item["RegistrarLockStatus"]
  end
end

class NamecheapDomainCheckResponse < NamecheapResponse
  def items
    super.collect {|item| DomainCheck.new(item[1])} 
  end
end

class NamecheapDomainLockStatusResponse < NamecheapResponse
  def items
    super.collect {|item| LockCheck.new(item[1])}
  end
end

class NamecheapTopLevelDomainResponse < NamecheapResponse
  def items
    super.collect {|item| TopLevelDomain.new(item[1])}
  end
end

class Namecheap
  attr_reader :username, :key, :client_ip
  def initialize(options = {})
    config = YAML.load_file("#{File.dirname(__FILE__)}/namecheap.yml")
    @username = config['username']
    @client_ip = config['client_ip']
    @key = config['key']
  end
  
  def is_domain_locked?(domain)
    # must be a domain associated with your account
    domain_check_lock_status(domain).items.first.status
  end
  
  def domain_check_lock_status(domain)
    NamecheapDomainLockStatusResponse.new(do_query("namecheap.domains.getRegistrarLock", "&DomainName=#{domain}"))
  end

  def is_domain_available?(domain)
    results = domain_check(domain).items
    results.nil? ? false : results.first.available
  end

  def domain_check(domain)
    domain = domain.join(",") if domain.is_a? Array
    NamecheapDomainCheckResponse.new(do_query("namecheap.domains.check", "&DomainList=#{domain}"))
  end

  protected
  
  def do_query(api_method, options=nil)
    query = "https://api.sandbox.namecheap.com/xml.response?ApiUser=#{@username}&ApiKey=#{@key}&UserName=#{@username}&ClientIp=#{@client_ip}&Command=#{api_method}"
    if !options.nil?
      query += options
    end
    HTTParty.get(query)
  end

end
