# Инструкция по настройке проекта на сервере Hetzner

## Переустановка сервера

Купив сервер у Hetzner, на нем необходимо переустановить систему для изменения
настроек разбивки дисков.

В [панели управления серверами][panel], в разделе [Servers][servers]
найдите ваш сервер. Во вкладке `IPs` сервера запоните первый адрес.
Допустим этим адресом является `144.76.8.196`.

Во вкладке `Rescue` активируйте 64-битную систему восстановления и запомните
пароль выданный после активации.

Во вкладке `Reset` выполните `Execute a automatic hardware reset`.

Через некоторое время сервер перезагрузится со системой востановления.
Присоеденитесь к серверу через ssh используя записаный ранее пароль.

```
$ ssh root@144.76.8.196
```

Запустите процесс переустановки системы:

```
root@rescue ~ # installimage
```

Выберите систему `Ubuntu`. Выберите версию `Ubuntu-1204-precise-64-minimal`.
После предупреждения откроется редактор с настройкой процесса установки.
В этом файле удалите следующие строчки:

```
HOSTNAME Ubuntu-1204-precise-64-minimal
PART swap swap 16G
PART /boot ext3 512M
PART / ext4 1024G
PART /home ext4 all
```

Строчки можно удалять используя клавишу `F8`. Вместо удаленных строчек впишите
следующие:

```
HOSTNAME host0.skveez.net
PART /boot ext2 512M
PART lvm sysvg 36G
PART lvm virvg all
LV sysvg root / ext3 32G
LV sysvg swap swap swap all
```

Сохраните настройки используя клавишу `F10`. Дважды согласитесь
с предупреждением. После этого начнется установка:

```

                Hetzner Online AG - installimage

  Your server will be installed now, this will take some minutes
             You can abort at any time with CTRL+C ...

         :  Reading configuration                           done 
   1/15  :  Deleting partitions                             done 
   2/15  :  Test partition size                             done 
   3/15  :  Creating partitions and /etc/fstab              done 
   4/15  :  Creating software RAID level 1                  done 
   5/15  :  Creating LVM volumes                            busy   No volume groups found
                                                            done 
   6/15  :  Formatting partitions
         :    formatting /dev/md/0 with ext2                done 
         :    formatting /dev/sysvg/root with ext3          done 
         :    formatting /dev/sysvg/swap with swap          done 
   7/15  :  Mounting partitions                             done 
   8/15  :  Extracting image (local)                        done 
   9/15  :  Setting up network for eth0                     done 
  10/15  :  Executing additional commands
         :    Generating new SSH keys                       done 
         :    Generating mdadm config                       done 
         :    Generating ramdisk                            done 
         :    Generating ntp config                         done 
         :    Setting hostname                              done 
  11/15  :  Setting up miscellaneous files                  done 
  12/15  :  Setting root password                           done 
  13/15  :  Installing bootloader grub                      done 
  14/15  :  Running some ubuntu specific functions          done 
  15/15  :  Clearing log files                              done 

                  INSTALLATION COMPLETE
   You can now reboot and log in to your new system with
  the same password as you logged in to the rescue system.

```

Перезагрузите сервер:

```
root@rescue ~ # reboot
```

После перезагрузки сервер будет с нужной версией ОС и правильной разбивкой
дисков.

[panel]: https://robot.your-server.de
[servers]: https://robot.your-server.de/server

## Создание пользователя

Если вы используете Linux или OS X, то удалите запись о сервере из файла
`~/.ssh/known_hosts`. Запись начинается примерно так:

`144.76.8.196 ssh-rsa AAAAB3NzaC1yc2EAAAA`.

Присоеденитесь к серверу:

```
$ ssh root@144.76.8.196
```

Создайте своего пользователя, например `vyacheslav`, задайте ему пароль
и сделайте его администратором системы:

```
root@host0 ~ # useradd -ms /bin/bash vyacheslav
root@host0 ~ # passwd vyacheslav
root@host0 ~ # adduser vyacheslav admin
```

Удалите пароль пользователя `root` и отключитесь от сервера.

```
root@host0 ~ # passwd -d root
root@host0 ~ # exit
```

## Настройка виртуализации

Присоеденитесь к серверу под созданным пользователем:

```
$ ssh 144.76.8.196
```

Обновите систему и установите необходимые пакеты:

```
vyacheslav@host0:~$ sudo aptitude update
vyacheslav@host0:~$ sudo aptitude upgrade -y
vyacheslav@host0:~$ sudo aptitude install -y qemu-kvm libvirt-bin
```

Разрешите своему пользователю управлять настройками виртуализации:

```
vyacheslav@host0:~$ sudo adduser vyacheslav libvirtd
```

Включите ip forwarding:

```
vyacheslav@host0:~$ echo net.ipv4.ip_forward=1 | sudo tee -a /etc/sysctl.conf
vyacheslav@host0:~$ echo net.ipv6.conf.all.proxy_ndp=1 | sudo tee -a /etc/sysctl.conf
vyacheslav@host0:~$ sudo sysctl -p
```

<!-- В панели управления серверами, в разделе `Servers`, во вкладке `IPs` узнайте
второй IP адрес вашего сервера. Если его нет, докупите его.

Допустим у нас есть следующие адреса для IPv4:

* `144.76.8.196` — адрес машины;
* `144.76.8.220` — дополнительный адрес;
* `255.255.255.224` — маска подсети.

Тогда выполните следующие комманды для настройки сети:

```
vyacheslav@host0:~$ virsh net-destroy default
vyacheslav@host0:~$ virsh net-undefine default
vyacheslav@host0:~$ cat << END | sudo tee /etc/libvirt/qemu/networks/default.xml
<network>
  <name>default</name>
  <forward/>
  <bridge name="virbr0"/>
  <ip address="192.168.122.1" netmask="255.255.255.0">
    <dhcp>
      <range start="192.168.122.10" end="192.168.122.99" />
      <host mac="52:54:00:f3:07:10" name="chef0.skveez.net" ip="192.168.122.10" />
      <host mac="52:54:00:f3:07:20" name="application0.skveez.net" ip="192.168.122.20" />
      <host mac="52:54:00:f3:07:30" name="database0.skveez.net" ip="192.168.122.30" />
      <host mac="52:54:00:f3:07:40" name="session0.skveez.net" ip="192.168.122.40" />
      <host mac="52:54:00:f3:07:50" name="balancer0".skveez.net ip="192.168.122.50" />
    </dhcp>
  </ip>
</network>
END
vyacheslav@host0:~$ cat << END | sudo tee /etc/libvirt/qemu/networks/hetzner.xml
<network>
  <name>hetzner</name>
  <bridge name="virbr1"/>
  <forward mode="route" dev="eth0"/>
  <ip address="144.76.8.196" netmask="255.255.255.224">
    <dhcp>
      <host mac="52:54:00:f3:07:50" name="balancer0" ip="144.76.8.220" />
    </dhcp>
  </ip>
</network>
END
vyacheslav@host0:~$ virsh net-define /etc/libvirt/qemu/networks/default.xml
vyacheslav@host0:~$ virsh net-define /etc/libvirt/qemu/networks/hetzner.xml
vyacheslav@host0:~$ virsh net-autostart default
vyacheslav@host0:~$ virsh net-autostart hetzner
``` -->

Скачайте образ установочного диска для последующих установок гостевых систем:

```
vyacheslav@host0:~$ sudo mkdir /var/iso
vyacheslav@host0:~$ cd /var/iso
vyacheslav@host0:/var/iso$ sudo wget --trust-server-names "http://www.ubuntu.com/start-download?distro=server&bits=64&release=lts"
vyacheslav@host0:/var/iso$ cd
```

Перезагрузите систему для применения всех настроек:

```
vyacheslav@host0:~$ sudo reboot
```

## Установка гостевой системы

В первую очередь необходимо устанавить гостевую систему для Chef.

Создайте диск:

```
vyacheslav@host0:~$ sudo lvcreate -L 8G -n chef0-root virvg
vyacheslav@host0:~$ sudo lvcreate -L 1G -n chef0-swap virvg
```

Выполните следующие комманды для настройки гостевой ситемы:

```
vyacheslav@host0:~$ ISO=$(ls /var/iso/ubuntu*)
vyacheslav@host0:~$ cat << END | sudo tee /etc/libvirt/qemu/chef0.xml
<domain type="kvm">
  <name>chef0</name>
  <memory>786432</memory>
  <os>
    <type>hvm</type>
  </os>
  <features>
    <acpi/>
  </features>
  <devices>
    <disk type="block" device="disk">
      <source dev="/dev/virvg/chef0-root"/>
      <target dev="vda"/>
      <boot order="1"/>
    </disk>
    <disk type="block" device="disk">
      <source dev="/dev/virvg/chef0-swap"/>
      <target dev="vdb"/>
    </disk>
    <disk type="file" device="cdrom">
      <source file="$ISO"/>
      <target dev='hda'/>
      <boot order="2"/>
      <readonly/>
    </disk>
    <interface type="network">
      <mac address='52:54:00:f3:07:10'/>
      <source network="default"/>
    </interface>
    <graphics type="vnc" port="5910" listen="127.0.0.1"/>
  </devices>
</domain>
END
vyacheslav@host0:~$ virsh define /etc/libvirt/qemu/chef0.xml
vyacheslav@host0:~$ virsh autostart chef0
```

Для создания тунелля к VNC гостевой системы выполните следующие комманды:

```
vyacheslav@host0:~$ exit
$ ssh 144.76.8.196 -L 5910:127.0.0.1:5910
```

Подключитесь через ваш VNC клиент к адресу 127.0.0.1:5910 и вы увидите
стандартный процесс установки Ubuntu Server. Выполните установку системы
по вашему усмотрению. Не забудьте отметить `OpenSSH server` во время установки.

По аналогии устанавливаются и остальные гостевые системы. Настройки для каждой
из необходимых систем приведены [ниже](#chef0).

## Настройка Сhef

Присоеденитесь к гостевой системе chef0:

```
vyacheslav@host0:~$ ssh chef0
```

Добавьте репозиторий Opscode:

```
vyacheslav@chef0:~$ echo "deb http://apt.opscode.com/ `lsb_release -cs`-0.10 main" | sudo tee /etc/apt/sources.list.d/opscode.list
vyacheslav@chef0:~$ gpg --keyserver keys.gnupg.net --recv-keys 83EF826A
vyacheslav@chef0:~$ gpg --export packages@opscode.com | sudo tee /etc/apt/trusted.gpg.d/opscode-keyring.gpg > /dev/null
vyacheslav@chef0:~$ sudo aptitude update
vyacheslav@chef0:~$ sudo aptitude install opscode-keyring
```

Обновите систему и выполните перезагрузку:

```
vyacheslav@chef0:~$ sudo aptitude upgrade
vyacheslav@chef0:~$ sudo reboot
```

После перезагрузки заново присоеденитесь к системе:

```
vyacheslav@host0:~$ ssh chef0
```

Установите Chef:

```
vyacheslav@chef0:~$ sudo aptitude install chef chef-server-api chef-expander
```

Во время установки вас спросят адрес сервера Chef, введите
`http://chef0.skveez.net:4000`. Пароль для AMPQ введите произвольный.

Настройте Knife:

```
vyacheslav@chef0:~$ mkdir -p ~/.chef
vyacheslav@chef0:~$ sudo cp /etc/chef/validation.pem /etc/chef/webui.pem ~/.chef
vyacheslav@chef0:~$ sudo chown -R vyacheslav ~/.chef
vyacheslav@chef0:~$ knife configure --initial \
  --defaults \
  --server-url http://chef0.skveez.net:4000 \
  --admin-client-key ~/.chef/webui.pem \
  --validation-key ~/.chef/validation.pem \
  --repository ""
vyacheslav@chef0:~$ rm ~/.chef/webui.pem
```


_**TODO:** проверить /etc/hosts на database0 database0.skveez.net_

## Конфигурации гостевых систем

### chef0

```
vyacheslav@host0:~$ sudo lvcreate -L 8G -n chef0-root virvg
vyacheslav@host0:~$ sudo lvcreate -L 1G -n chef0-swap virvg
vyacheslav@host0:~$ ISO=$(ls /var/iso/ubuntu*)
vyacheslav@host0:~$ cat << END | sudo tee /etc/libvirt/qemu/chef0.xml
<domain type="kvm">
  <name>chef0</name>
  <memory>786432</memory>
  <os>
    <type>hvm</type>
  </os>
  <features>
    <acpi/>
  </features>
  <devices>
    <disk type="block" device="disk">
      <source dev="/dev/virvg/chef0-root"/>
      <target dev="vda"/>
      <boot order="1"/>
    </disk>
    <disk type="block" device="disk">
      <source dev="/dev/virvg/chef0-swap"/>
      <target dev="vdb"/>
    </disk>
    <disk type="file" device="cdrom">
      <source file="$ISO"/>
      <target dev='hda'/>
      <boot order="2"/>
      <readonly/>
    </disk>
    <interface type="network">
      <mac address='52:54:00:f3:07:10'/>
      <source network="default"/>
    </interface>
    <graphics type="vnc" port="5910" listen="127.0.0.1"/>
  </devices>
</domain>
END
vyacheslav@host0:~$ virsh define /etc/libvirt/qemu/chef0.xml
vyacheslav@host0:~$ virsh autostart chef0
```

### application0

```
vyacheslav@host0:~$ sudo lvcreate -L 16G -n application0-root virvg
vyacheslav@host0:~$ sudo lvcreate -L 2G -n application0-swap virvg
vyacheslav@host0:~$ ISO=$(ls /var/iso/ubuntu*)
vyacheslav@host0:~$ cat << END | sudo tee /etc/libvirt/qemu/application0.xml
<domain type="kvm">
  <name>application0</name>
  <memory>2097152</memory>
  <os>
    <type>hvm</type>
  </os>
  <features>
    <acpi/>
  </features>
  <devices>
    <disk type="block" device="disk">
      <source dev="/dev/virvg/application0-root"/>
      <target dev="vda"/>
      <boot order="1"/>
    </disk>
    <disk type="block" device="disk">
      <source dev="/dev/virvg/application0-swap"/>
      <target dev="vdb"/>
    </disk>
    <disk type="file" device="cdrom">
      <source file="$ISO"/>
      <target dev='hda'/>
      <boot order="2"/>
      <readonly/>
    </disk>
    <interface type="network">
      <mac address='52:54:00:f3:07:20'/>
      <source network="default"/>
    </interface>
    <graphics type="vnc" port="5920" listen="127.0.0.1"/>
  </devices>
</domain>
END
vyacheslav@host0:~$ virsh define /etc/libvirt/qemu/application0.xml
vyacheslav@host0:~$ virsh autostart application0
```
