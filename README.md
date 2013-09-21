
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
