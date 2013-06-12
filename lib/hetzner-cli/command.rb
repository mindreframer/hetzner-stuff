require 'hetzner-cli/command/kickstart'
require 'hetzner-cli/command/distributions'

module HetznerCli
  module Command
    include Kickstart
    include Distributions
  end
end
