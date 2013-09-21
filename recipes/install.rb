if node['tinc']['ppa']
  include_recipe "tinc::ppa"
end

package "tinc"
