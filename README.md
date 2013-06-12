# Hetnzer CLI
## Purpose
[Hetzner](http://www.hetzner.de) is a hoster that allows you to get 'real' physical machines instead of all the 'virtualized' cloud stuff.
This is especially handy for testing virtualization stuff.

They provide a 'REST' like api that you can use to call separate tasks , like reset a server, install linux etc..
For most of the simple tasks,one could get away with using 'curl', but some tasks (like re-installing a server) require more coordination

1. purpose #1 : of this is to automate these 'combined' hetnzer tasks via CLI instead of using their webinterface.
2. purpose #2 : me to learn better their api and potentially put this into [fog](http://fog.io)
3. purpose #3 : extend [mccloud](http://github.com/jedi4ever/mccloud) to allow for Hetnzer support

## Tasks implemented

### Distributions

      Usage:
      hetzner-cli distributions IP --password=PASSWORD --user=USER

      Options:
      --user=USER              # Hetzner Admin Username
      --password=PASSWORD      # Hetzner Admin Password
      [--robot-url=ROBOT_URL]  # URL to connect to hetzner robo service
    # Default: https://robot-ws.your-server.de/

      List availble distributions for IP

### Kickstart
The tasks of re-installing a server from scratch and putting an initial ssh key on it

      Usage:
      hetzner-cli kickstart IP --dist=DIST --password=PASSWORD --user=USER

      Options:
      [--lang=LANG]            # Architecture to use
    # Default: en
    [--arch=ARCH]            # Architecture to use (32|64)
    # Default: 64
      --user=USER              # Hetzner Admin Username
      --password=PASSWORD      # Hetzner Admin Password
      [--robot-url=ROBOT_URL]  # URL to connect to hetzner robo service
    # Default: https://robot-ws.your-server.de/
      [--key-file=KEY_FILE]    # SSH key to install as root user
    # Default: /Users/patrick/.ssh/id_dsa.pub
      --dist=DIST              # Distribution to use

  Re-install server with IP

## Todo

  - obviously make it catch errors more and write tests
  - potentially integrate the functionality into fog with a hetzner provider
  - look into using the hetzner-api plugin to leverage all the API calls
