#!/usr/bin/env python

"""
tinc_rollout.py
============

This script sets up or updates a host to connect to a tinc vpn.  It
allows you to start a network from scratch, join an existing network,
decide which peers you will connect with, and can package up your tinc
configuration so others can join the network too.

This is aimed at users who just want to make a bunch of boxes talk to
each other.  It won't setup bridging between two segments or anything
like that.

You should run this script as root (or any other user who is allowed
to write to /etc/tinc).  This script creates files in the current
directory, so you should run it from /etc/tinc (or use the --root
parameter to specify that directory).

Creating A New Network
----------------------

If you want to make a network from scratch (as opposed to joining an
existing network), use the "new" command:

tinc_rollout.py --new -n network_name --hostname your_hostname --ip xxx.xxx.xxx.xxx

The IP address is how your box will be known on the vpn.  It should
probably begin with 10. or 198.162 or 17.16.  Your hostname is the
name you would like to be called on your network.  If you already have
a hostname in /etc/hostname, you might want to just use that.

Joining An Existing Network
---------------------------

tinc_rollout.py --install -n network_name --ip xxx.xxx.xxx.xxx --tar path/to/tinc_rollout.tar

The tinc_rollout.tar file should be provided by somebody else in the
vpn.  It contains some basic configuration and the host keys for peer
nodes.  This will create the network if needed and copy host files to
it so you can accept connections with that network.

Any time two machines want to talk to each other, they will need to
have each other's keys.

Adding Nodes To Your Network
----------------------------

If in the future new machines join your vpn, simply drop their
host file in /etc/tinc/network_name/hosts or do another "tinc_rollout.py
--install" right on top of your existing config.

Inviting Others Into the Network
--------------------------------

After you do the install, you might want to use the "package" command
to add your host key to the tinc_rollout.tar file.  Then you can give
that file to other folks to configure their own tinc nodes.


Bugs and Todos
--------------

I wrote and tested this on Debian Wheezy.  Patches welcome for other
systems, but fixes, or new capabilities!  Grep the code for 'TODO' to
get a list of future work.

TODO: support ipv6
TODO: auto update the package
TODO: auto download the package
TODO: send package back to maintainer
TODO: hosts-available/hosts-enabled

Import Tinc Rollout
-------------------

If you want to use these routines in your python script, you probably
want to do something like this:

    from tinc_rollout import TincRollout

    TR=TincRollout({'root':'/etc/tinc',
                    'vpn_name':'freedombox'})
    print TR.get_host_name()
    print TR.get_host_file()



License and Copyright
---------------------

This software is Copyright (c) 2012-2013 James Vasile.  It is
published under the terms of the GNU General Public License, version 3
or later.  A copy of the latest version of that license should be
available at http://www.gnu.org/licenses/gpl.html See COPYING for
details.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
General Public License for more details.

Thanks
------

Big thanks to Eben Moglen.  I can't count the number of times he told
me to look at tinc over the last few years and especially in the
FreedomBox context.  I just wish I'd gotten to it sooner.
"""

import sys, os, subprocess, argparse, tarfile, stat, logging, re

## This is just defaults that is used by argparse
tar_file = os.path.basename(sys.argv[0])+".tar"

def slurp_if_exists(fname):
    if os.path.exists(fname):
        with open(fname, 'r') as INF:
            return INF.read()


class chdir:
    def __enter__(self):
        self.curdir = os.getcwd()
        os.chdir(self.direc)
        return None
    def __init__(self, direc):
        self.direc = direc
    def __exit__(self, type, value, traceback):
        os.chdir(self.curdir)

class NoHostnameError(Exception):
    pass
class NoVPNNameError(Exception):
    pass

class SingleLevelFilter(logging.Filter):
    """Licensed under the MIT License (http://opensource.org/licenses/mit-license.php)
    From https://code.google.com/p/sqlalchemy-migrate/source/browse/migrate/versioning/shell.py?r=38dca475c55333aab047d65503a15c470170336d"""
    def __init__(self, min=None, max=None):
        self.min = min or 0
        self.max = max or 100

    def filter(self, record):
        return self.min <= record.levelno <= self.max

def config_logger():
    global log
    h1 = logging.StreamHandler(sys.stdout)
    f1 = SingleLevelFilter(max=logging.INFO)
    h1.addFilter(f1)
    rootLogger = logging.getLogger()
    rootLogger.addHandler(h1)
    h2 = logging.StreamHandler(sys.stderr)
    f2 = SingleLevelFilter(min=logging.WARN)
    h2.addFilter(f2)
    rootLogger.addHandler(h2)
    log = logging.getLogger("my.logger")
    log.setLevel(logging.INFO)

def parse_params(argv=None):
    if not argv:
        argv = sys.argv

    parser = argparse.ArgumentParser(description='Add/remove machines from your tinc vpn network.')
    act = parser.add_mutually_exclusive_group()
    act.add_argument('--add', dest='action', help='Start a new tinc vpn or install machines into an existing tinc vpn', action='store_const', const='add')
    #act.add_argument('--remove', dest='action', help='remove machines from the tinc vpn', action='store_const', const='remove') #TODO: implement remove
    act.add_argument('--package', dest='action', help='tar up the vpn configuration for export', action='store_const', const='package')

    # options for all actions
    parser.add_argument('-n', '--name', dest="vpn_name", default=None, action='store',
                        help='the name of the vpn (maps to tincd -n)')
    parser.add_argument('--root', default='.', help="Where your tinc config dir is. Defaults to current dir")

    # options for add actions
    parser.add_argument('--hostname', help='Hostname of this machine on the vpn (defaults to /etc/hostname)')
    parser.add_argument('--ip', help="internal (vpn) IP address of this node")
    parser.add_argument('--peer', action='append', default=[],
                        help='peer node to add or remove. May be specified more than once. Default is all known possible peers.')
    parser.add_argument('--tar', default=tar_file,
                        help="path to tar file containing tinc.conf and host keys. If blank, we'll look for %s." % tar_file)

    parser.add_argument('-v', '--verbose', dest='verbose', action='store_true')

    args = parser.parse_args()

    if args.verbose:
        log.setLevel(logging.DEBUG)

    if not args.vpn_name:
        sys.stderr.write("Must provide the name of a vpn to operate on.\n")
        sys.exit()
        raise NoVPNNameError

    if not args.action:
        parser.print_usage()

    if not args.hostname:
        args.hostname = slurp_if_exists("/etc/hostname").strip()
    if not args.hostname:
        sys.stderr.write("Cannot figure out your hostname.  Please provide one.\n")
        sys.exit()
        raise NoHostnameError

    if args.action == 'add':
        if not args.ip:
            sys.stderr.write("Must provide ip address of this machine on the vpn (e.g. 172.16.xx.xx).\n")
            sys.exit()
        
    return args

class TincRollout():
    def __init__(o, opt=None):
        if isinstance(opt, dict):
            o.__dict__.update(opt)
        elif opt:
            o.__dict__.update(vars(opt))
        #log.debug("o.root = %s" % o.root)
        o.vpn_dir = os.path.abspath(os.path.join(o.root, o.vpn_name))
        #log.debug("o.vpn_dir = %s" % o.vpn_dir)
        o.hosts_dir = os.path.join(o.vpn_dir, 'hosts')

    def gen_keys(o):
        ## Gen keys if needed
        machine_file = os.path.join(o.vpn_dir, "hosts", o.hostname)
        key_file = os.path.join(o.vpn_dir, "rsa_key.priv")
        gen_keys = True
        if os.path.exists(key_file) and os.path.exists(machine_file):
            found_subnet=False
            found_key = False
            with open(machine_file, 'r') as INF:
                for line in INF.readlines():
                    if line.startswith("Subnet"):
                        found_subnet = True
                    if line.strip() == "-----BEGIN RSA PUBLIC KEY-----":
                        found_key = True
            if found_subnet and found_key:
                #log.info("%s already exists.  No need to generate keys." % machine_file)
                gen_keys = False
        if gen_keys: # ugly ugly ugly
            if os.path.exists(key_file):
                os.unlink(key_file)
            with open(machine_file, 'w') as OUTF:
                OUTF.write("Subnet = %s/32\n" % o.ip)
            subprocess.call('tincd -n "%s" --generate-keys' % o.vpn_name, shell=True)

    def add_nets_boot(o):
        """Add vpn to nets.boot"""
        nets_file = os.path.join(o.root, "nets.boot")
        if not os.path.exists(nets_file):
            with open(nets_file, 'a') as OUTF:
                OUTF.write(o.vpn_name + "\n")
        else:
            with open("nets.boot", 'r') as INF:
                lines = INF.readlines()
            found = False
            for line in lines:
                if line.strip() == o.vpn_name:
                    found = True
            if not found:
                with open(nets_file, 'a') as OUTF:
                    OUTF.write(o.vpn_name + "\n")

    def get_host_name(o):
        """Returns name of this machine in the tinc network, as
        specified in the tinc.conf file."""
        for line in slurp_if_exists(os.path.join(o.vpn_dir,"tinc.conf")).split("\n"):
            if not '=' in line:
                continue
            (key, val) = line.split("=")
            if key.strip() == "Name":
                return val.strip()

    def get_host_file(o):
        """Returns contents of host file for this machine.  Assumes
        network name is freedombox and it's all in o.vpn_dir"""
        
        return slurp_if_exists(os.path.join(o.vpn_dir, "hosts", o.get_host_name()))

    def add_peer(o, peer_name, contents):
        """Adds contents as a hosts file with the given peer_name to
        the tinc vpn named vpn_name."""
        with open(os.path.join(os.path.join(o.vpn_dir, "hosts", peer_name)), 'w') as OUT:
            OUTF.write(contents)


class Package(TincRollout):
    def package(o):
        log.info("Packaging %s for sending to other machines." % o.vpn_name)
        if os.path.exists(o.tar):
            os.unlink(o.tar)
        with tarfile.open(o.tar, mode='w') as OUT:
            with chdir(o.vpn_dir):
                for f in os.listdir(o.hosts_dir):
                    if not f.endswith("~"):
                        fname = os.path.join('hosts', f)
                        OUT.add(fname)

class Add(TincRollout):    
    def add_peers(o):
        """Add host key files for peers.  Overwrites files that
        already exists.  Doesn't write local host file."""

        if not os.path.exists(o.tar):
            log.warn("Can't find %s, which is fine if this is a new vpn installation" % o.tar)
            return
        with tarfile.open(o.tar, 'r') as TAR:
            for member in TAR.getmembers():
                (direc, fname) = os.path.split(member.name)
                if fname != o.hostname:
                    if not o.peer or fname in o.peer:
                        ## Sure, we could use TAR.extractall, but
                        ## reading the data and then writing the host
                        ## file protects against malicious tar files
                        ## with absolute paths in them.
                        contents = TAR.extractfile(member).read()
                        o.add_peer(member.name, contents)
                        
    def add_connect_to(o):
        """Look at hosts in hosts dir, add any that have addresses to tinc.conf.

        We can't just look at the tar file because there might be
        additional hosts that were added by hand or just happen to be
        missing from the tar file.

        Assumes tinc.conf exists so we can add ConnectTo entries.
        """

        connect = []
        for f in os.listdir(o.hosts_dir):
            fname = os.path.join(o.hosts_dir, f)
            with open(fname, 'r') as INF:
                for line in INF.readlines():
                    if line.startswith("Address = "): #TODO: this should be a regex
                        connect.append(f)

        present = []
        with open(os.path.join(o.vpn_dir, 'tinc.conf'), 'r+') as INF:
            for line in INF.readlines():
                if line.startswith("ConnectTo = "):
                    present.append(line.split('=')[1].strip())
            for host in connect:
                if not host in present:
                    INF.write("ConnectTo = %s\n" % host)

    def add(o):
        log.info("Adding %s tinc files" % o.vpn_name)
        o.hostname = re.sub('[^0-9a-zA-Z_]+', '_', "%s" % o.hostname) # Replace invalid characters for the tinc daemon name with underscores
        NewVPN(o).create() # do a base install w/o overwriting keys or config
        o.add_peers()
        o.add_connect_to()
                    
        log.info("\nIf this machine has a public-facing IP address, you might want to add that to %s." % os.path.join(o.root, o.vpn_name, "hosts", o.hostname)
                 + "If your machine was not in the tar file, you might want to do `%s --package -n %s` to "  % (os.path.basename(sys.argv[0]), o.vpn_name)
                 + "put your machine in the tar file.  Then you can distribute the tar to get others on to the network."
                 + "\nYou should probably restart the tinc server now.")

class Remove(TincRollout):
    def remove(o):
        log.error("Removing hosts not yet implemented.")

class NewVPN(TincRollout):
    """Do a base install, without overwriting existing keys or hosts."""
    def write_config(o, fname):
        filespec = os.path.join(o.vpn_dir, fname)
        d = {
            "tinc-up":"#!/bin/sh\nIP=%s\nifconfig $INTERFACE $IP netmask 255.255.255.0\n" % o.ip,
            "tinc-down":"#!/bin/sh\nVPN_NAME=%s\nifconfig $VPN_NAME down\n" % o.vpn_name,
            "tinc.conf":"Name = %s\nAddressFamily = ipv4\nDevice = /dev/net/tun\nLocalDiscovery = yes\n" % o.hostname,
            }
        if os.path.exists(filespec):
            contents = slurp_if_exists(filespec)
            if d[fname] != contents:
                log.warn("%s already exists. Delete %s and run command again if you want to overwrite." % (filespec, filespec))
            return
        with open(filespec, 'w') as OUTF:
            OUTF.write(d[fname])
        if fname in ['tinc-up', 'tinc-down']:
            os.chmod(filespec, os.stat(filespec).st_mode | stat.S_IEXEC)
    def write_host(o):
        fname = os.path.join(o.hosts_dir, o.hostname)
        if not os.path.exists(fname):
            with open(fname, 'w') as OUTF:
                OUTF.write("Subnet = %s/32\n" % o.ip)

    def create(o):
        o.add_nets_boot()
        if not os.path.exists(o.vpn_dir):
            os.mkdir(o.vpn_dir)
        o.write_config('tinc.conf')
        o.write_config('tinc-up')
        o.write_config('tinc-down')
        if not os.path.exists(o.hosts_dir):
            os.mkdir(o.hosts_dir)
        o.write_host()
        o.gen_keys()

def main(argv):
    config_logger()
    opt = parse_params(argv)
    if opt.action == "package":
        Package(opt).package()
    elif opt.action == "add":
        Add(opt).add()
    elif opt.action == "remove":
        Remove(opt).remove()
if __name__ == "__main__":
    if sys.argv[1] == "document":
        with open("README.md", 'w') as OUTF:
            OUTF.write(__doc__)
        sys.exit()

    main(sys.argv)
