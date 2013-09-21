#
#    Copyright (C) 2012 eNovance <licensing@enovance.com>
#
#    Author: Loic Dachary <loic@dachary.org>
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU Affero General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU Affero General Public License for more details.
#
#    You should have received a copy of the GNU Affero General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# How to write documentation
# http://docs.puppetlabs.com/guides/style_guide.html#puppet-doc
#
# == Define: l2mesh
#
# Create and update L2 ( http://en.wikipedia.org/wiki/Link_layer )
# mesh. The mesh named *lemesh* will show as a new interface on each
# machine participating in the mesh, as a new ethernet interface. For
# instance:
#
#   $ ip link show dev lemesh
#   4: lemesh: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast
#      link/ether 72:75:6e:60:59:f0 brd ff:ff:ff:ff:ff:ff
#
# The interface is created by a *tincd* daemon ( one per mesh ) which
# maintains a connection to all other machines in the mesh.
#
# Given three bare metal machines hosted at http://hetzner.de/,
# http://ovh.fr/ and http://online.net/, *l2mesh* can be used to
# create a new ethernet interface *lemesh* on each of them that
# behaves as if they had a physical ethernet card connected to one
# hardware switch in the same room. The machine at *hetzner* could be
# the DHCP server providing the IP for the *lemesh* interface of the
# OVH machine. In addition, if the connection between the *hetzner*
# machine and the *ovh* machine does not work, the packets will use
# the *online* machine as an intermediary, making the mesh resilient
# to network outage.
#
# tinc is not limited to the use case implemented by this module, see
# http://www.tinc-vpn.org/ for more information.
#
# == Parameters
#
# [*name*] name of the mesh
#
# [*ip*] ip address of the node
#
# [*port*] port number used by each tincd
#        (see the tinc.conf manual page for more information)
#
# [*tcp*] Whether to use TCP instead of UDP
#
# == Example
#
#  include l2mesh::params
#  l2mesh { 'lemesh':
#      ip               => $::ipaddress_eth0,
#      port		=> 655,
#  }
#
# == Starting and reloading the tinc daemon
#
# There is one daemon for each mesh and all of them are run by a
# single /etc/init.d/tinc script which is uncommon. To cope with this
# situation, a combination of calls to the /etc/init.d/tinc script and
# the *tincd* binary is used, as follows:
#
# [add a mesh] when a new mesh is created, no daemon is running for
#       it. When tincd tries to signal it with USR1 to check for its
#       existence, it will fail. /etc/init.d/tinc is called and will
#       attempt to start all mesh. It will fail for all but the newly
#       created, because they already run. But it will succeed for the
#       newly created mesh, which is the intended outcome.
#
# [reboot and shutdown] The init script will loop over all mesh and
#       start / stop them.
#
# [configuration change] The status of the deamon for which a
#      configuration file was changed is tested by sending it the USR1
#      signal. If sending the signal fails, the mesh will be started
#      as if it has just been created. If sending the signal succeeds,
#      the daemon will be sent the HUP signal and will gracefully
#      reload the configuration files. In particular it will notice a
#      change in the list of tincd peers it must connect to.
#
# [remove a mesh] there is no support to remove a mesh other than
#      removing the files and exported resources from the puppet
#      database manually.
#
# == Generating and distributing keys ==
#
# Each host participating in the mesh has a public / private keypair.
# The pair is generated on the puppetmaster by the *tinc_keygen*
# function located in the
# *l2mesh/lib/puppet/parser/functions/tinc_keygen.rb* source file
# and stored in */var/lib/puppet/l2mesh*, under a
# directory dedicated to the node owning the keypair. The
# *tinc_keygen* function is called each time the manifest containing
# it is compiled. If the files containing the keypair already
# exist, the key is not generated again. For instance, the
# */var/lib/puppet/l2mesh/there/bm0003there/rsa_key.pub* file contains
# the public part of the key for the node *bm0003there* in the *there*
# mesh.
#
# The keypair must be copied over to the node that owns it and
# the manifest takes care of it with file {} classes. The public
# part of the keypair must be copied to each node that is willing
# to accept connections from the node that owns it. Since the goal
# of the l2mesh module is to create a mesh where each node
# are connected with each other, the public key will be copied
# to each node participating in the mesh and included in the
# corresponding host file. For instance, the public key of
# the node *bm0003there* of the *there* mesh will be included in the file
# */etc/tinc/there/hosts/bm0003there* file.
#
# == Supported Operating Systems
#
# * Debian GNU/Linux
#
# Support for new operating systems can be implemented by adding a new
# section in the *l2mesh/manifests/params.pp* file.
#
# == Security and disaster recovery
#
# [the puppetmaster crashes] the */var/lib/puppet* directory will be
#   lost and all the keypairs with it. If the puppetmaster is reconstructed
#   but the content of */var/lib/puppet* cannot be recovered, the keys
#   for all hosts will be recreated.
#
# [impersonating a node] the keypairs are distributed from the puppetmaster
#   to the nodes and a node that would succeed in fooling the puppetmaster
#   into thinking it is the legitimate recipient of a keypair could enter
#   the mesh. If the puppetmaster can be sollicited by untrusted hosts,
#   using node selection based on fully qualified host names is a must.
#   For instance, instead of *node /www/* it is recommended to append
#   the top level domain name *node /www.*foo.com$/* otherwise any node
#   with a *www* in the name can enter the mesh.
#
# == TODO / Roadmap
#
# * Add support to remove a mesh which implies removing the associated
#   exported resources
#
# * Test for exported resources
#   https://groups.google.com/forum/#!topic/puppet-users/XgQXt5n017o[1-25]
#
# * Format and publish this documentation
#
# * What if a node is not reachable from the internet ? All other nodes
#   will have a ConnectTO trying to reach it and this is a waste of
#   resources although it does not break the mesh.
#
# * Add a test that checks if instantiating two lmesh does not run into
#   a conflict ( l2mehs(ip = 1) + l2mesh(ip = 2) ). How is it done with
#   rspec puppet ?
#
# == Dependencies
#
#   Class['concat']
#
# == Authors
#
# Loic Dachary <loic@dachary.org>
# - Original Author
#
# Mike Green <myatus@gmail.com>
# - Added TCPOnly option, general cleanup
#
# == Copyright
#
# Copyright 2012 eNovance <licensing@enovance.com>
#

define l2mesh(
  $ip,
  $port,
  $tcp_only = 'no',
) {

  include l2mesh::params

  $package = $l2mesh::params::tinc_package_name

  if ! defined(Package[$package]) {
    package { $package:
      ensure => present,
    }
  }

  $start    = "start_${name}"
  $reload   = "reload_${name}"

  $running  = "tincd --net=${name} --kill=USR1"

  $boots    = '/etc/tinc/nets.boot'
  $root     = "/etc/tinc/${name}"
  $hosts    = "${root}/hosts"
  $conf     = "${root}/tinc.conf"

  $tag      = "tinc_${name}"
  $tag_conf = "${tag}_connect"

  $fqdn = regsubst($::fqdn, '[._-]+', '', 'G')
  $host = "${hosts}/${fqdn}"

  $private     = "${root}/rsa_key.priv"
  $public      = "${root}/rsa_key.pub"
  $keys        = tinc_keygen("${l2mesh::params::keys_directory}/${name}/${fqdn}")
  $private_key = $keys[0]
  $public_key  = $keys[1]

  exec { $start:
    command	 => "tincd --net=${name} && ${running}",
    onlyif	 => "! ${running}",
    provider => 'shell',
    require  => File[$conf]
  }

  exec { $reload:
    command	=> "tincd --net=${name} --kill=HUP",
    provider	=> 'shell',
    refreshonly	=> true,
  }

  if ! defined(Concat[$boots]) {
    concat { $boots:
      owner => root,
      group => 0,
      mode	=> '0400';
    }
  }

  concat::fragment { "${boots}_${name}":
    target	=> $boots,
    content	=> "${name}\n",
  }

  if ! defined(File[$root]) {
    file { $root:
      ensure  => 'directory',
      owner   => root,
      group   => root,
      mode    => '0755',
      require => Package[$package],
    }
  }

  file { $hosts:
    ensure      => 'directory',
    owner       => root,
    group       => root,
    mode        => '0755',
    require	=> File[$root],
  }

  file { $private:
    owner   => root,
    group   => root,
    mode    => '0400',
    content => $private_key,
    notify	=> Exec[$reload],
    before  => Exec[$start],
  }

  file { $public:
    owner   => root,
    group   => root,
    mode    => '0444',
    content => $public_key,
    notify	=> Exec[$reload],
    before  => Exec[$start],
  }

  # Add host files
  @@file { $host:
    owner   => root,
    group   => root,
    mode    => '0444',
    require => File[$hosts],
    notify	=> Exec[$reload],
    before  => Exec[$start],
    tag     => $tag,
    content     => "Address = ${ip}
Port = ${port}
Compression = 0
TCPOnly = ${tcp_only}

${public_key}
",

  }

  File <<| tag == $tag |>>

  # Build tinc.conf file, adding hosts except localhost
  concat { $conf:
    owner   => root,
    group   => root,
    mode    => 444,
    require => File[$root],
    notify	=> Exec[$reload],
  }

  concat::fragment { "${conf}_head":
    target  => $conf,
    content => "Name = ${fqdn}
AddressFamily = ipv4
Device = /dev/net/tun
Mode = switch

",
  }

  @@concat::fragment { "${tag_conf}_${fqdn}":
    target  => $conf,
    tag     => "${tag_conf}_${fqdn}",
    content => "ConnectTO = ${fqdn}\n",
  }

  Concat::Fragment <<| tag != "${tag_conf}_${fqdn}" |>>
}
