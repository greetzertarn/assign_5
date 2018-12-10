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

# using loop from https://stackoverflow.com/questions/2379829/while-loop-to-test-if-a-file-exists-in-bash
while [ ! -f /scratch/munge.key ]
do
  sleep 5
done
sudo cp /scratch/munge.key /etc/munge

#correcting permissions
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

# checking that rpms have been moved then installing them
while [ ! -f /scratch/rpmMove.txt ] 
do
  sleep 5
done
sudo yum --nogpgcheck localinstall /software/slurm-rpms/* -y

# copying slurm.conf file
sudo cp /local/repository/source/slurm.conf /etc/slurm


# setting up configurations and files
sudo mkdir /var/spool/slurmd
sudo chown slurm: /var/spool/slurmd
sudo chmod 755 /var/spool/slurmd
sudo touch /var/log/slurmd.log
sudo chown slurm: /var/log/slurmd.log

sudo touch /var/run/slurmd.pid
sudo chmod 777 /var/run/slurmd.pid
sudo chown slurm: /var/run/slurmd.pid

# disabling firewall
sudo systemctl stop firewalld
sudo systemctl disable firewalld

# syncing clocks
sudo yum install ntp -y
sudo chkconfig ntpd on
sudo ntpdate pool.ntp.org
sudo systemctl start ntpd

#enable slurm daemon
while [ ! -f /scratch/dbd.fin ]
do
  sleep 5
done
# trying to start slurm
sudo systemctl enable slurmd.service
sudo systemctl start slurmd.service
sudo systemctl status slurmd.service

sudo touch /scratch/d.fin

