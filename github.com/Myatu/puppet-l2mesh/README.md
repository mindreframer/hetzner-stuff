<!-- -*- mode: markdown -*- -->
Introduction
============

[l2mesh](http://redmine.the.re/projects/l2mesh "l2mesh") is a
[tinc](http://www.tinc-vpn.org/ "tinc") based virtual switch,
implemented as a puppet module. 

It creates a new ethernet interface on the machine and connects it to
the switch.

Here is how the situation looks like when dealing with physical
machines and a hardware switch:


    +----------------+                        +---------------+
    |                |                        |               |
    |          +-----+                        +-----+         |
    | MACHINE  | eth0+---------+    +---------+eth0 | MACHINE |
    |    A     +-----+         |    |         +-----+   C     |
    |                |         |    |         |               |
    +----------------+     +---+----+---+     +---------------+
                           |  SWITCH    |
                           +-----+------+
                                 |
    +----------------+           |
    |                |           |
    |          +-----+           |
    | MACHINE  | eth0+-----------+
    |    B     +-----+
    |                |
    +----------------+
  
Each of the three machines ( *A, B, C* ) have a physical ethernet
connector which shows as *eth0*. They are connected with a cable to a
*SWITCH* which transmits the packet coming from *MACHINE A* to *MACHINE B*
or *MACHINE C*. 

With *l2mesh*, a new virtual interface ( named *L2M* below ) is
created on each machine and they are all connected by a [TINC daemon](http://www.tinc-vpn.org/). 
Packets go from *MACHINE A* to *MACHINE B* or *MACHINE C* as if they were
connected to a physical switch.

    +---------+-----+
    |         |eth0 |
    |         +-----+
    | MACHINE | L2M |
    |    A    +-----+
    |           TINC+---
    +--------------++   \-------
                   |            \-------   +---------------+
                   |                    X--+TINC           |
                   |            /-------   +-----+         |
     +-------------+-+   /------           | L2M | MACHINE |
     |           TINC+---                  +-----+    C    |
     |         +-----+                     |eth0 |         |
     | MACHINE | L2M |                     +-----+---------+
     |    B    +-----+
     |         |eth0 |
     +---------+-----+

Here is how it looks on each machine:

    $ ip link show eth0
    2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP qlen 1000
       link/ether fa:16:3e:48:ae:6f brd ff:ff:ff:ff:ff:ff

    $ ip link show dev L2M
    2: L2M: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast
       link/ether 72:75:6e:60:59:f0 brd ff:ff:ff:ff:ff:ff

Usage
=====

*l2mesh* is a puppet module that should be installed in the puppet master as follows

    git clone http://redmine.the.re/git/l2mesh.git /etc/puppet/modules/l2mesh

Here is an example usage that can be included in */etc/puppet/manifests/site.pp*

    node /MACHINE-A.example.com/, /MACHINE-B.example.com/ {
      include l2mesh::params
      
      l2mesh { 'L2M':
        ip                  => $::ipaddress_eth0,
        port                => 656,
      }
    }

On both *MACHINE-A* and *MACHINE-B*, it will 

* create the *L2M* ethernet interface 
* run the *tincd* daemon to listen on port *656* and
  bind it to the *$::ipaddress_eth0* IP address

In addition, both machines will try to reach each other:

* *tincd* on *MACHINE-A* will try to connect to *tincd* on *MACHINE-B*
* *tincd* on *MACHINE-B* will try to connect to *tincd* on *MACHINE-A*

Adding a new machine to the *L2M* virtual switch is done by adding the
hostname of the machine to the node list. For instance,
*MACHINE-C.example.com* can be added with:

    node /MACHINE-A.example.com/, /MACHINE-B.example.com/, /MACHINE-C.example.com/  {
    ...

l2mesh is not
=============

* l2mesh is not an equivalent to *brctl* : it is a switch made of *tinc* daemons running on multiple machines

* l2mesh does not know anything about IP addresses or L3 routing. Here is a puppet snippet that shows how to assign IP addresses to an interface created by l2mesh, using the hostname to figure it out. For instance, bm0001.the.re will have the IP 192.168.100.1, bm0002.the.re will have the IP 192.168.100.2 etc. This is done by creating a *tinc-up* script that is run by *tincd* each time the interface is up.

          $private_ip = regsubst($::fqdn, '^bm0+(\d+).*', '192.168.100.\1')
        
          file { '/etc/tinc':
            ensure      => 'directory',
            owner       => root,
            group       => root,
            mode        => '0755',
            before      => L2mesh['L2M'],
          }
        
          file { '/etc/tinc/L2M':
            ensure      => 'directory',
            owner       => root,
            group       => root,
            mode        => '0755',
            require     => File['/etc/tinc'],
          }
        
          file { '/etc/tinc/L2M/tinc-up':
            owner       => root,
            group       => root,
            mode        => '0544',
            content     => "#!/bin/bash                                                                                                                                         
        ifconfig L2M ${private_ip} netmask 255.255.255.0                                                                                                                      
        ",
            require     => File['/etc/tinc/L2M'],
          }
        
Implementation
==============

See the implementation notes at the beginning of the file [manifests/init.pp](http://redmine.the.re/projects/l2mesh/repository/revisions/master/entry/manifests/init.pp "manifests/init.pp")

License
=======

    Copyright (C) 2012 eNovance <licensing@enovance.com>

	Author: Loic Dachary <loic@dachary.org>

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU Affero General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Affero General Public License for more details.

    You should have received a copy of the GNU Affero General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.


Running tests
=============

    GEM_HOME=$HOME/.gem-installed gem install --include-dependencies --no-rdoc --no-ri puppet  puppet-lint rspec-puppet rspec-expectations mocha puppetlabs_spec_helper rake
    export PATH=$HOME/.gem-installed/bin:$PATH ; GEM_HOME=$HOME/.gem-installed rake spec
