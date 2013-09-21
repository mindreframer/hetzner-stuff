## Tinc:

apt-get install -y build-essential
apt-get install -y texinfo
apt-get install -y zlibc zlib1g zlib1g-dev
apt-get install -y liblzo2-dev
apt-get install -y libssl-dev


git clone https://github.com/gsliepen/tinc.git
cd tinc
autoreconf -fsi
./configure --prefix=
make
make install



## Tutorials/Posts
  - [Static IP Tinc VPN on Debian Wheezy](http://blog.philippgoecke.de/?p=651)
  - http://blogs.operationaldynamics.com/andrew/software/research/using-tinc-vpn
  - [inc: the difficulties of a peer-to-peer VPN on the hostile Internet](http://www.youtube.com/watch?v=R7P_vvz1AP8)

  - http://blog.chr.istoph.de/tag/tinc/
  - http://www.linux-magazin.de/Ausgaben/2003/10/Einfache-Verbindung
  - http://augsburg.freifunk.net/hilfe/setup-access-point/tinc-vpn-fuer-die-vernetzung-von-funkinseln.html
  - http://www.admin-magazin.de/Das-Heft/2009/02/Virtual-Private-Networks-mit-Tinc
  - [Large Sites with Tinc](http://www.tinc-vpn.org/pipermail/tinc/2013-February/003204.html)
  - http://blog.geniedb.com/2012/09/27/geniedb-and-geo-distributed-replication/

## Discussions
  - [Automatic configuration of direct routes behind NAT - Network Tinc User](http://t8732.network-tinc-user.networktalks.us/automatic-configuration-of-direct-routes-behind-nat-t8732.html)


## Code
  - https://github.com/ryd/chaosvpn
  - https://github.com/gsliepen/tinc
  - https://github.com/Youscribe/tinc-cookbook
  - https://github.com/makefu/shack-retiolum


## Papers
  - [On the Design and Implementation of Structured P2P VPNs](http://arxiv.org/pdf/1001.2575.pdf)

## Talks
  - http://tinc-vpn.org/presentations/
  - https://archive.fosdem.org/2011/schedule/event/ec2_vpn
  - http://tinc-vpn.org/presentations/fosdem-2011/ec2_vpn_fosdem2011.pdf


## Patches:
  - http://www.tinc-vpn.org/pipermail/tinc/2011-February/002646.html

## Emails
  - http://www.tinc-vpn.org/pipermail/tinc/

### Alternative/Additions Software
  - PWnat
    - http://samy.pl/pwnat/
    - http://resources.infosecinstitute.com/udp-hole-punching/
  - Vtun
    - http://my.safaribooksonline.com/book/operating-systems-and-server-administration/linux/0596004613/networking/linuxsvrhack-chp-4-sect-8
