#!/usr/bin/ruby -w
# coding: utf-8
require "Server"

BEGIN{
	SERVERS = [Server.new("worker-node-sergio-1", "ACTIVE", "128.142.153.89")]

	SERVERS_COUNT = 1 # se utiliza para asignar ID secuenciales a las máquinas que harán de servidor web

	MAX_TRESHOLD = 6.0
	MIN_TRESHOLD = 1.0
}

def monitor_servers
	check_server_status() # comprueba el estado de los servidores en OpenStack
	
	loads = []
	SERVERS.each do |server|
		if server.status == "ACTIVE"
			loads << get_server_load(server.hostname)			
	end

	avg_load = loads.inject(:+) / loads.length
	if avg_load >= MAX_TRESHOLD
		"start_server"
	elsif avg_load <= MIN_TRESHOLD
		"shutdown_server"
	else
		"OK"
	end
end

def check_server_status()
	SERVERS.each do |server|
		status = get_server_status(server)
		if status == "ACTIVE" && server.status == "BUILD" # si el servidor se acaba de activar
			server.status = status
			server.ip = get_server_ip(server)
			add_proxy_cofiguration(server)
		end
	end
end

def get_server_status(server)
	status = ""
	raw_info = `nova show '#{server.hostname}'`
	lines = raw_info.split("\n")
	if lines.length > 1
		status_columns = lines[3].split("|")
		status = status_columns[2].strip
	end
	status
end

def get_server_ip(server)
	ip = ""
	raw_info = `nova show '#{server.hostname}'`
	lines = raw_info.split("\n")
	if lines.length > 1
		network_columns = lines[19].split("|")
		ip = status_columns[2].strip
	end
	ip
end

def add_proxy_configuration(server)
	proxy_configuration = `cat /etc/haproxy/haproxy.cfg`
	new_server = "    server #{server.hostname} #{server.ip}:3000 maxconn 32"
	proxy_configuration += "\n" + new_server

	exec("echo '#{proxy_configuration}' > /etc/haproxy/haproxy.cfg") # se sobreescribe la configuración antigua
	exect("service haproxy reload") # recargamos el servicio haproxy
end

def get_server_load(hostname, username = "root")
	output = `ssh -i estudiante19.pem #{username}@#{hostname} cat /proc/loadavg`
    (output.split(" ")[1]).to_f
end

def start_server
	boot_command = "nova boot --user-data cloudinit-boot-script --image 17754e8c-364a-40fc-8a1f-f6a48a481374 --flavor m1.small --key-name estudiante19 "
		+ "worker-node-sergio-#{SERVERS_COUNT + 1}"
	
	exec(boot_command)

	SERVERS << Server.new("worker-node-sergio-#{SERVERS_COUNT + 1}", "BUILD", "")
	SERVERS_COUNT = SERVERS_COUNT + 1
end

def shutdown_server
	puts "Shutdown server"
end

while true do
	action = monitor_servers
	if(action == "start_server")
		start_server
	elsif(action == "shutdown_server")
		shutdown_server
	end
end