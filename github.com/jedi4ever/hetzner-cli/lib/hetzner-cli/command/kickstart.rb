module HetznerCli
  module Kickstart

    require 'pp'
    require 'faraday'
    require 'json'
    require 'net/ssh'

    def _kickstart(ip,options)
      user = options['user']
      password = options['password']
      robot_url = options['robot_url']
      dist = options['dist']
      lang = options['lang']
      arch = options['arch']
      key_file = options['key_file']
      key = ''

      # Reading keyfile
      begin
        key = File.read(key_file)
      rescue Error => ex
        $stderr.puts "[#{ip}] Error reading key_file"
        exit -1
      end

      # Create connection
      conn = Faraday.new(:url => robot_url) do |faraday|
        faraday.request  :url_encoded             # form-encode POST params
        #faraday.response :logger                  # log requests to STDOUT
        faraday.adapter  Faraday.default_adapter  # make requests with Net::HTTP
      end

      # Set credentials
      conn.basic_auth(user,password)

      # Check if new installation was already requested
      unless installing?(conn,ip)

        # Get a list of available distributions
        puts "[#{ip}] Available distributions:"
        response = conn.get("/boot/#{ip}")
        boot_info = JSON.parse(response.body)
        distributions = boot_info['boot']['linux']['dist']
        distributions.each do |distro|
          puts "[#{ip}] - #{distro}"
        end

        # Bail out if the distribution specified is not listed
        unless distributions.include?(dist)
          $stderr.puts "[#{ip}] The specified distribution '#{dist}' is not available for server with"
          exit -1
        else
          puts "[#{ip}] Distribution selected: #{dist}"
        end

        # Trigger a new linux install on reboot
        puts "[#{ip}] Activating new linux install: distribution '#{dist}', arch '#{arch}', lang '#{lang}'"
        response = conn.post("/boot/#{ip}/linux", { :dist => dist , :arch => arch , :lang => lang})
        linux_info = JSON.parse(response.body)
        new_password = linux_info['linux']['password']

        puts "[#{ip}] Sending hw reset"
        # Hardware reboot the system
        response = conn.post("/reset/#{ip}", { :type => 'hw'})

        # Allowing the system to go down, saves us from checking bad authentication errors
        puts "[#{ip}] New Password : #{new_password}"

        begin
          fully_booted = false
          print "[#{ip}] Waiting for the linux install to finish and reboot: "
          STDOUT.flush
          4.times {
            sleep 5
            print '.'
            STDOUT.flush
          }
          while !fully_booted do
            sleep 5
            print '.'
            STDOUT.flush
            begin
              # Ignoring new key
              Net::SSH.start(ip,'root',:password => new_password , :paranoid => false, :timeout => 5  ) do |ssh|
                motd = ssh.exec!("cat /etc/motd")
                motd = "" if motd.nil?
                unless motd.include?('rescue')
                  output = ssh.exec!("cat /root/.ssh/authorized_keys2")
                  if output.include?("No such file")
                    puts
                    puts "[#{ip}] Install is finished and system is available"
                    puts "[#{ip}] Installing root ssh key"
                    output = ssh.exec!("echo '#{key}' > /root/.ssh/authorized_keys")
                    fully_booted = true
                  end
                end
              end
            rescue Net::SSH::Disconnect,Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Errno::ECONNABORTED, Errno::ECONNRESET, Errno::ENETUNREACH,Errno::ETIMEDOUT,IOError,Timeout::Error,Net::SSH::AuthenticationFailed
              #Ignoring these errors
            end
          end
        end
        puts "[#{ip}] System is ready for login"
        puts "[#{ip}] You might want to cleanup your old key:"
        puts "[#{ip}] ssh-keygen -R #{ip}"
        puts "[#{ip}] ssh-keyscan #{ip} >> $HOME/.ssh/known_hosts"
      else
        $stderr.puts "[#{ip}] Installation already in progress, aborting"
        exit -1
      end
    end

    def installing?(conn,ip)
      response = conn.get("/boot/#{ip}/linux")
      linux_info = JSON.parse(response.body)
      return linux_info['linux']['active'] == true
    end
  end
end
