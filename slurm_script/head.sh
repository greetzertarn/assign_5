#!/bin/bash

# the folliwng came from https://www.slothparadise.com/how-to-install-slurm-on-centos-7-cluster/

sudo yum install mariadb-server mariadb-devel -y


# created global users so UID and GID is consistent across every node
export MUNGEUSER=991
sudo groupadd -g $MUNGEUSER munge
sudo useradd  -m -c "MUNGE Uid 'N' Gid Emporium" -d /var/lib/munge -u $MUNGEUSER -g munge  -s /sbin/nologin munge
export SLURMUSER=992
sudo groupadd -g $SLURMUSER slurm
sudo useradd  -m -c "SLURM workload manager" -d /var/lib/slurm -u $SLURMUSER -g slurm  -s /bin/bash slurm

# install epel-release because we're using CentOS
sudo yum install epel-release

# installing munge
sudo yum install munge munge-libs munge-devel -y

# install tools to create the secret munge key
sudo yum install rng-tools -y
sudo rngd -r /dev/urandom

# create key
sudo /usr/sbin/create-munge-key -r
sudo dd if=/dev/urandom bs=1 count=1024 > /etc/munge/munge.key
sudo chown munge: /etc/munge/munge.key
sudo chmod 400 /etc/munge/munge.key

# send the key to shared directory
sudo cp /etc/munge/munge.key /scratch

# correcting permissions
sudo chown -R munge: /etc/munge/ /var/log/munge/
sudo chmod 0700 /etc/munge/ /var/log/munge/

# starting the service
sudo systemctl enable munge
sudo systemctl start munge

# installing slurm dependencies
sudo yum install openssl openssl-devel pam-devel numactl numactl-devel hwloc -y
sudo yum install hwloc-devel lua lua-devel readline-devel rrdtool-devel ncurses-devel man2html libibmad libibumad -y
sudo yum install pam-devel -y
sudo yum install 'perl(ExtUtils::Embed)' -y

# installing the LATEST version of slurm into shared software folder
cd /software
sudo wget https://download.schedmd.com/slurm/slurm-18.08.3.tar.bz2
sudo yum install rpm-build
sudo rpmbuild -ta slurm-18.08.3.tar.bz2

# moving rpms for installation on server and compute nodes
cd /root/rpmbuild/RPMS/x86_64
sudo mkdir /software/slurm-rpms
sudo cp * /software/slurm-rpms

# create file to check that rpms have been moved
sudo echo "I am done" > /scratch/rpmMove.txt

# install rpms
sudo yum --nogpgcheck localinstall /software/slurm-rpms/* -y

# copying slurm.conf file
cd ~
sudo cp /local/repository/source/slurm.conf /etc/slurm

# setting configurations and files
sudo mkdir /var/spool/slurmctld
sudo chown slurm: /var/spool/slurmctld
sudo chmod 755 /var/spool/slurmctld
sudo touch /var/log/slurmctld.log
sudo chown slurm: /var/log/slurmctld.log
sudo touch /var/log/slurm_jobacct.log /var/log/slurm_jobcomp.log
sudo chown slurm: /var/log/slurm_jobacct.log /var/log/slurm_jobcomp.log
# PID PROBLEM AGAIN
sudo touch /var/run/slurmctld.pid
sudo chown slurm: /var/run/slurmctld.pid
sudo chmod 777 /var/run/slurmctld.pid


# open slurm default ports
sudo firewall-cmd --permanent --zone=public --add-port=6817/udp
sudo firewall-cmd --permanent --zone=public --add-port=6817/tcp
sudo firewall-cmd --permanent --zone=public --add-port=6818/tcp
sudo firewall-cmd --permanent --zone=public --add-port=6818/tcp
sudo firewall-cmd --permanent --zone=public --add-port=7321/tcp
sudo firewall-cmd --permanent --zone=public --add-port=7321/tcp
sudo firewall-cmd --reload

# syncing clocks
sudo yum install ntp -y
sudo chkconfig ntpd on
sudo ntpdate pool.ntp.org
sudo systemctl start ntpd

# waiting for compute nodes to start, don't know if this is required
while [ ! -f /scratch/compute_done.txt ] 
do
  sleep 5
done
sudo touch /scratch/compute_done.txt

# trying to start slurm 
sudo systemctl enable slurmctld.service
sudo systemctl start slurmctld.service
sudo systemctl status slurmctld.service

#notify metadata slurmctld daemon is up
sudo touch /scratch/head.fin

#wait for callback from metadata
while [ ! -f /scratch/cluster.fin ]
do
  sleep 5
done

# restart slurmctld daemon
sudo systemctl restart slurmctld

