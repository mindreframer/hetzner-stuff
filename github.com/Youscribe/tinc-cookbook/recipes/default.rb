#
# Cookbook Name:: tinc
# Recipe:: default
#
# Author:: Guilhem Lettron <guilhem.lettron@youscribe.com>
#
# Copyright 20012, Societe Publica.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

include_recipe "tinc::install"

# Before lucid, ruby doesn't include openssl
if node['platform'] == "ubuntu" and node['platform_version'].to_f <= 10.04
  package "libopenssl-ruby" do
    action :install
  end
end

if node['platform'] == "ubuntu" and node['platform_version'].to_f >= 9.04
  include_recipe "tinc::upstart"
end  

# we don't need to edit nets.boot if we use /etc/network/interfaces
if ! node['recipes'].include?("network_interfaces")
  template "/etc/tinc/nets.boot" do
    source "nets.boot.erb"
    owner "root"
    group "root"
    mode "0644"
    variables(
      :networks => node['tinc']['net'].keys.reject do |key| key == "default" end
    )
  end
else
  template "/etc/tinc/nets.boot" do
    source "nets.boot.erb"
    owner "root"
    group "root"
    mode "0644"
    variables(
      :networks => []
    )
  end
end

node['tinc']['net'].each do |network, conf|
  next if network == "default"

#  databagItem = search("tinc_#{network}", 'id:' + node.name.gsub(".","DOT")).first
#  # If databag doesn't exist, we create it with default values
#  ruby_block "create databagItem" do
#    block do
#      databagItemIdeal = {
#        "id" => node.name.gsub(".","DOT"),
#        "name" => Tinc.attribute_value('name', network, node),
#        "external_ipaddress" => Tinc.attribute_value('external_ipaddress', network, node),
#        "subnets" => Tinc.attribute_value('subnets', network, node),
#        "internal_ipaddress" => Tinc.attribute_value('internal_ipaddress', network, node),
#        "public_key" => Tinc.attribute_value('public_key',network, node)
#      }
#      databagItem = Chef::DataBagItem.new
#      databagItem.data_bag("tinc_" + network)
#      databagItem.raw_data = databagItemIdeal
#      databagItem.save
#    end
#    only_if { databagItem == nil }
#  end

  directory "/etc/tinc/#{network}/hosts" do
    owner "root"
    group "root"
    mode "0644"
    recursive true
  end

#  Chef::Log.debug("hosts_ConnectTo = #{Tinc.conf_value('hosts_ConnectTo', network, node).inspect}")

  template "/etc/tinc/#{network}/tinc.conf" do
    source "tinc.conf.erb"
    mode "0644"
    owner "root"
    group "root"
    variables(
      :hosts_ConnectTo => Tinc.conf_value('hosts_ConnectTo', network, node),
      :device => Tinc.conf_value('device', network, node),
      :external_ipaddress => Tinc.public_value('external_ipaddress', network, node, node),
      :interface => Tinc.conf_value('interface', network, node),
      :bind_to => Tinc.conf_value('bind_to', network, node),
      :mode => Tinc.conf_value('mode', network, node),
      :name => Tinc.conf_value('name', network, node)
    )
    notifies :run, "execute[reload tinc]"
  end

  # Generate a rsa pub/sec key only 1 time
  ruby_block "generate_key" do
    block do
      require 'openssl'
      rsa_key = OpenSSL::PKey::RSA.new(2048)
      public_key = rsa_key.public_key
      ::File.open("/etc/tinc/#{network}/rsa_key.priv","w") do |f| 
        f.chmod(0600)
        f.write(rsa_key) 
      end
      node.set['tinc']['net'][network]['public_key'] = public_key
      node.save
    end
  # TODO generate with specif BITS
  #  notifies(:reload, "service[tinc]")
    not_if { conf.has_key?('public_key') }
  end

  search_filter = "recipes:tinc AND tinc_net:#{network}"
  case node['tinc']['select']
  when 'attribute'
    search_filter = "recipes:tinc AND tinc_net:#{network}"
  when 'chef_environement'
    search_filter = "chef_environment:#{node.chef_environment} AND recipes:tinc AND tinc_net:#{network}"
  when 'role'
    search_filter = "role:#{node['tinc']['role']}"
  end

  template "/etc/tinc/#{network}/hosts/#{Tinc.public_value('name', network, node, node)}" do
    source "host.erb"
    mode "0644"
    owner "root"
    group "root"
    variables(
      :ipaddress => Tinc.public_value('external_ipaddress', network, node, node),
      :cipher => Tinc.public_value('cipher', network, node, node),
      :digest => Tinc.public_value('digest', network, node, node),
      :compression => Tinc.public_value('compression', network, node, node),
      :subnets => Tinc.public_value('subnets', network, node, node),
      :tcponly => Tinc.public_value('tcponly', network, node, node),
      :public_key => Tinc.public_value('public_key',network, node, node)
    )
    notifies :run, "execute[reload tinc]"
  end

  search(:node, search_filter) do |workingnode|
    template "/etc/tinc/#{network}/hosts/#{Tinc.public_value('name', network, workingnode, node)}" do
      source "host.erb"
      mode "0644"
      owner "root"
      group "root"
      variables(
        :ipaddress => Tinc.public_value('external_ipaddress', network, workingnode, node),
        :cipher => Tinc.public_value('cipher', network, workingnode, node),
        :digest => Tinc.public_value('digest', network, workingnode, node),
        :compression => Tinc.public_value('compression', network, workingnode, node),
        :subnets => Tinc.public_value('subnets', network, workingnode, node),
        :tcponly => Tinc.public_value('tcponly', network, workingnode, node),
        :public_key => Tinc.public_value('public_key',network, workingnode, node)
      )
      notifies :run, "execute[reload tinc]"
    end
  end

  if node[:recipes].include?("network_interfaces")
    network_interfaces Tinc.conf_value('interface', network, node) do
      target Tinc.conf_value('internal_ipaddress', network, node)
      mask Tinc.conf_value('internal_netmask', network, node)
#      mtu 1452
      custom "tinc-net" => "#{network}", "dns-nameservers" => "172.16.0.4", "dns-search" => "societe-publica.server"
      #TODO my configuration :/ sorry, my bad, I have no good way "for the moment"
    end
  elsif node[:tinc][:init] != "none"
    service "tinc-network-#{network}" do
      pattern "tinc.conf"
      start_command "initctl start tinc NETWORK=\"#{network}\" || initctl status tinc NETWORK=\"#{network}\""
      stop_command "initctl stop tinc NETWORK=\"#{network}\""
      reload_command "initctl reload tinc NETWORK=\"#{network}\""
      restart_command "initctl restart tinc NETWORK=\"#{network}\""
      supports :reload => true, :restart => true
      provider Chef::Provider::Service::Upstart
      notifies(:add, "ifconfig[#{conf[:internal_ipaddress]}]")
      action [:start]
    end
  
    ifconfig Tinc.conf_value('internal_ipaddress', network, node) do
      device Tinc.conf_value('interface', network, node)
      mask Tinc.conf_value('internal_netmask', network, node)
      # old command
      #command "ifconfig #{net[:interface]} #{net[:internal_ipaddress} #{net[:subnets][0]}"
      action :nothing
    end
  end
end

execute "reload tinc" do
  command "ps aux | grep -v grep | grep -q tincd && ( pkill -HUP tincd && pkill -WINCH tincd ) || true"
  action :nothing
end
