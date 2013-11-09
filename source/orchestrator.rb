#!/usr/bin/ruby -w
# coding: utf-8

BEGIN{
	SERVERS = ["appserver1.cern.ch"]
	MAX_TRESHOLD = 6.0
	MIN_TRESHOLD = 1.0
}

def get_server_load(server, username = "root")
	output = exec("ssh #{username}@#{server} cat /proc/loadavg")    
    (loads.split()[1]).to_f
end

def monitor_servers
	loads = []
	SERVERS.each do |server|
		loads << get_server_load(server)
	end
	avg_loads = loads.inject(:+) / loads.length

	if avg_loads >= MAX_TRESHOLD
		"start_server"
	elsif avg_loads <= MIN_TRESHOLD
		"shutdown_server"
	else
		"OK"
	end
end

def start_server
end

def shutdown_server
end

action = monitor_servers
if(action == "start_server")
	start_server
elsif(action == "shutdown_server")
	shutdown_server
end