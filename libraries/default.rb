class Chef::Recipe::Tinc

def self.search_hosts_ConnectTo(network,node)
  hosts = []
  Chef::Search::Query.new.search(:node, "recipes:tinc\\:\\:core AND tinc_net:#{network}") do |searchnode| # AND chef_environment:#{@node.chef_environment}
#    Chef::Log.debug("ConnectTo #{self.public_value('name',network,searchnode, node)}")
    hosts <<  self.public_value('name',network,searchnode,node)
  end
  return hosts
end

def self.conf_value(key,network,node)
  Chef::Log.debug("conf_value : #{key} in network #{network} for node #{node.name}")
  if key == 'hosts_ConnectTo'
    node['tinc']['net'][network].has_key?(key) ? node['tinc']['net'][network][key] : self.search_hosts_ConnectTo(network, node)
  else
    node['tinc']['net'][network].has_key?(key) ? node['tinc']['net'][network][key] : node['tinc']['net']['default'][key]
  end
end

def self.public_value(key,network,workingnode,node)
  Chef::Log.debug("Public_value : #{key} in network #{network} for node #{workingnode.name}")
  case key
  when 'subnets'
    substitute =  [ workingnode['tinc']['net'][network]['internal_ipaddress'] + "/32" ]
  when 'external_ipaddress'
    substitute =  workingnode['ipaddress']
  when 'name'
    substitute = workingnode['hostname'].gsub("-", "_")
  end

  if workingnode['tinc']['net'][network].has_key?(key)
    workingnode['tinc']['net'][network][key]
  elsif workingnode['tinc']['net']['default'].has_key?(key)
    workingnode['tinc']['net']['default'][key]
  elsif substitute
    substitute
  else
    Chef::Log.debug("No value for #{key}")
  end
end

def self.attribute_value(key,network,node)
  Chef::Log.debug("attribute_value : #{key} in network #{network} for node #{node.name}")
  if key == 'subnets'
    node['tinc']['net'][network].has_key?(key) ? node['tinc']['net'][network][key] : node['tinc']['net']['default'].has_key?(key) ? node['tinc']['net']['default'][key] : [ node['tinc']['net'][network]['internal_ipaddress'] + "/32" ]
  else
    node['tinc']['net'][network].has_key?(key) ? node['tinc']['net'][network][key] : node['tinc']['net']['default'][key]
  end
end

end
