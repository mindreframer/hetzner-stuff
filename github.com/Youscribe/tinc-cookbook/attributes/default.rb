default[:tinc][:net][:default][:device] = "/dev/net/tun"
default[:tinc][:net][:default][:interface] = "tun0"
default[:tinc][:net][:default][:bind_to] = "eth0"
default[:tinc][:net][:default][:mode] = "router"
default[:tinc][:net][:default][:name] = node[:hostname].gsub("-", "_")
default[:tinc][:net][:default][:external_ipaddress] = node[:ipaddress]

default[:tinc][:net][:default][:cipher] = "blowfish"
default[:tinc][:net][:default][:digest] = "sha1"
default[:tinc][:net][:default][:compression] = "0"

default[:tinc][:net][:default][:tcponly] = false

#default[:tinc][:net][:default][:internal_ipaddress] = "192.16.0.1"
default[:tinc][:net][:default][:internal_netmask] = "255.255.255.0"

case node[:platform]
when "debian"
  default[:tinc][:init] = "none"
  default['tinc']['ppa'] = false
when "ubuntu"
  default['tinc']['init'] = "other"
  default['tinc']['ppa'] = true
else
  default[:tinc][:init] = "other"
  default['tinc']['ppa'] = false
end
