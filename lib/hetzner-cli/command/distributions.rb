module HetznerCli
  module Distributions

    require 'pp'
    require 'faraday'
    require 'json'
    require 'net/ssh'

    def _distributions(ip,options)
      user = options['user']
      password = options['password']
      robot_url = options['robot_url']

      # Create connection
      conn = Faraday.new(:url => robot_url) do |faraday|
        faraday.request  :url_encoded             # form-encode POST params
        #faraday.response :logger                  # log requests to STDOUT
        faraday.adapter  Faraday.default_adapter  # make requests with Net::HTTP
      end

      # Set credentials
      conn.basic_auth(user,password)

      begin
        # Get a list of available distributions
        puts "[#{ip}] Available distributions:"
        response = conn.get("/boot/#{ip}")
        boot_info = JSON.parse(response.body)
        distributions = boot_info['boot']['linux']['dist']
        distributions.each do |distro|
          puts "[#{ip}] - #{distro}"
        end
      rescue Faraday::Error::ConnectionFailed => ex
        $stderr.puts "Error logging in #{ex}"
      end

    end

  end
end
