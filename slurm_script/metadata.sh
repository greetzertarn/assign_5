#!/bin/bash

# the folliwng came from https://www.slothparadise.com/how-to-install-slurm-on-centos-7-cluster/

sudo yum install mariadb-server mariadb-devel -y
sudo systemctl enable mariadb
sudo systemctl start mariadb

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
sudo cp /local/repository/source/slurmdbd.conf /etc/slurm

# setting up configurations and files
sudo mkdir /var/log/slurm
sudo chown slurm: /var/log/slurm
sudo chmod 755 /var/log/slurm
sudo touch /var/log/slurm/slurmdbd.log
sudo chown slurm: /var/log/slurm/slurmdbd.log
sudo chmod 755 /var/log/slurm/slurmdbd.log

# KEEPS ASKING FOR A PID??
sudo touch /var/run/slurmdbd.pid
sudo chown slurm: /var/run/slurmdbd.pid
sudo chmod 777 /var/run/slurmdbd.pid

# borrowed these from another group
sudo mysql  -sfu root < "/local/repository/slurm_script/setup.sql"
sudo mysql "-ppassword" < "/local/repository/slurm_script/metadb.sql"

# copies the innodb.cnf
sudo cp /local/repository/source/innodb.cnf /etc/my.cnf.d/innodb.cnf
sudo chown slurm: /etc/my.cnf.d/innodb.cnf
sudo chmod 777 /etc/my.cnf.d/innodb.cnf


# disabling firewall
sudo systemctl stop firewalld
sudo systemctl disable firewalld

# syncing clocks
sudo yum install ntp -y
sudo chkconfig ntpd on
sudo ntpdate pool.ntp.org
sudo systemctl start ntpd

# trying to start slurm
 sudo systemctl enable slurmdbd.service
 sudo systemctl start slurmdbd.service
