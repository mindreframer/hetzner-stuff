require 'rubygems'

require 'hetzner-cli/command'

module HetznerCli
  class CLI < Thor

    include HetznerCli::Command

    desc "kickstart IP", "Re-install server with IP"
    method_option :robot_url , :default => 'https://robot-ws.your-server.de/', :desc => "URL to connect to hetzner robo service"
    method_option :user, :desc => 'Hetzner Admin Username', :required => true
    method_option :password, :desc => 'Hetzner Admin Password', :required => true
    method_option :dist, :desc => "Distribution to use", :required => true
    method_option :arch, :default => '64', :desc => "Architecture to use (32|64)" 
    method_option :key_file, :default => File.join(ENV['HOME'],'.ssh','id_dsa.pub'), :desc => "SSH key to install as root user"
    method_option :lang, :default => 'en', :desc => "Architecture to use"

    def kickstart(ip)
      _kickstart(ip,options)
    end

    desc "distributions IP", "List availble distributions for IP"
    method_option :robot_url , :default => 'https://robot-ws.your-server.de/', :desc => "URL to connect to hetzner robo service"
    method_option :user, :desc => 'Hetzner Admin Username', :required => true
    method_option :password, :desc => 'Hetzner Admin Password', :required => true

    def distributions(ip)
      _distributions(ip,options)
    end

  end
end
