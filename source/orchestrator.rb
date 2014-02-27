#!/usr/bin/ruby -w
# coding: utf-8

BEGIN{
	MAX_TRESHOLD = 0.4
	MIN_TRESHOLD = 0.2

	SERVERS = []
}


class Server
	attr_accessor :hostname, :status, :ip
	def initialize(hostname, status, ip)
		@hostname, @status, @ip = hostname, status, ip
	end
end

def monitor_servers
	check_server_status # comprueba el estado de los servidores en OpenStack

	loads = []
	SERVERS.each do |server|
		if server.status == "ACTIVE"
			loads << get_server_load(server)
		end
	end

	avg_load = loads.inject(:+) / loads.length
	if avg_load > MAX_TRESHOLD
		"start_server"
	elsif avg_load < MIN_TRESHOLD && SERVERS.length > 1 && !is_last_active  # evitamos que se borre un servidor si es el único que queda
		"shutdown_server"                                                   # o es el único activo, aunque esté ocioso
	else
		"OK"
	end
end

def is_last_active
	actives = 0
	SERVERS.each do |server|
		actives += 1 if server.status == "ACTIVE"
	end
	actives == 1
end

def check_server_status
	SERVERS.each do |server|
		status = get_server_status(server)
		puts "El server '#{server.hostname}' tiene un estado '#{status}'."
		if status == "ACTIVE" && server.status == "BUILD" # si el servidor se acaba de activar
			server.status = status
			server.ip = get_server_ip(server)
			puts "El server '#{server.hostname}' tiene una IP '#{server.ip}'"
			add_proxy_configuration(server)
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
		ip = network_columns[2].strip
	end
	ip
end

def add_proxy_configuration(server)
	proxy_configuration = `cat /etc/haproxy/haproxy.cfg`
	new_server = "    server #{server.hostname} #{server.ip}:80 maxconn 32"
	proxy_configuration += "\n" + new_server

	`echo '#{proxy_configuration}' > /etc/haproxy/haproxy.cfg` # se sobreescribe la configuración antigua

	# reiniciamos manualmente el servicio de haproxy
	`service haproxy stop`
	sleep(2) # por precaución
	`service haproxy start`
end

def get_server_load(server, username = "root")
	output = `ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i estudiante19.pem #{username}@#{server.hostname} cat /proc/loadavg`
	load = (output.split(" ")[0]).to_f
	puts "La carga actual de '#{server.hostname}' es de '#{load}'"
	load
end

def start_server
	server_number = $servers_count + 1
	boot_command = "nova boot --user-data cloudinit-boot-script --image 17754e8c-364a-40fc-8a1f-f6a48a481374 --flavor m1.small --key-name estudiante19 worker-node-sergio-#{server_number}"

	puts "Se procede a crear un nuevo servidor web."
	puts "Se utilizará la orden [#{boot_command}]"

	`#{boot_command}`

	SERVERS << Server.new("worker-node-sergio-#{server_number}", "BUILD", "")
	$servers_count = server_number
end

def shutdown_server
	puts "Se procede a eliminar un servidor web."

	server_to_remove = nil
	SERVERS.each do |server|
		if server.status == "ACTIVE" && server.hostname != "worker-node-sergio-1" # facilita las labores de testing....
			load = get_server_load(server)
			if(load < MIN_TRESHOLD)
				server_to_remove = server
				break;
			end
		end
	end
	shutdown_server_instance(server_to_remove)
	remove_proxy_config(server_to_remove)
	SERVERS.delete(server_to_remove)
end

def shutdown_server_instance(server)
	shutdown_command = "nova delete '#{server.hostname}'"
	`#{shutdown_command}`
end

def remove_proxy_config(server)
	proxy_configuration = `cat /etc/haproxy/haproxy.cfg`
	remove_server = "    server #{server.hostname} #{server.ip}:80 maxconn 32"
	proxy_configuration = proxy_configuration.gsub(remove_server, "")

	`echo '#{proxy_configuration}' > /etc/haproxy/haproxy.cfg` # se sobreescribe la configuración antigua

	# reiniciamos manualmente el servicio de haproxy
	`service haproxy stop`
	sleep(2) # por precaución
	`service haproxy start`
end

SERVERS << Server.new("worker-node-sergio-1", "ACTIVE", "188.184.135.210")
$servers_count = 1 # se utiliza para asignar ID distinto a las máquinas que harán de servidor web
while true do
	action = monitor_servers
	if(action == "start_server")
		start_server
	elsif(action == "shutdown_server")
		shutdown_server
	end
end
