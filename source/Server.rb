class Server
	attr_accessor :hostname, :status, :ip
	def initialize(hostname, status, ip)
		@hostname, @status, @ip = hostname, status, ip
	end
end