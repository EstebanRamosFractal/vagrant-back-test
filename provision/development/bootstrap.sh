#!/bin/sh

############################
#
# API.CAREVIRTUE.VM
#
#  Development Bootstrap
#
#  Ubuntu 20.04
#  https://www.ubuntu.com/
#
#  Packages:
#   Python3 3.9
#   PostgreSQL 12
#   Nginx 1.17
#   vim tmux screen git zip
#   awscli
#   ansible
#   docker
#   elasticsearch
#   Stripe CLI
#
#  author: kchevalier@protonmail.com
#  date: September, 2020
#
############################


#################
#
# System Updates
#
#################

# get list of updates
apt update

# update all software
apt upgrade -y


################
#
# Install Tools
#
################

# install basic tools
apt install -y vim tmux screen git zip

# install AWS command line interface
apt install -y awscli


#####################
#
# Install PostgreSQL
#
#####################

# install PostgreSQL
apt install -y postgresql postgresql-contrib
apt install -y libpq-dev

# install PostGIS
apt install -y postgis postgresql-12-postgis-3

# create development user and databases
su postgres -c "psql -c \"CREATE USER api_admin WITH PASSWORD 'passpass';\""
su postgres -c "createdb api_db_dev -O api_admin"
su postgres -c "createdb api_db_test -O api_admin"

# allow PostgreSQL access for local development
ufw allow 5432
sed -i "s/^#\?listen_addresses =.*/listen_addresses = '*'/g" /etc/postgresql/12/main/postgresql.conf
echo "
# Allow all connections - DEVELOPMENT usage only
host    all             all              0.0.0.0/0                       md5
host    all             all              ::/0                            md5
" >> /etc/postgresql/12/main/pg_hba.conf
systemctl restart postgresql


#########################
#
# Install Elasticsearch
#
#########################

curl -fsSL https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -
echo "deb https://artifacts.elastic.co/packages/7.x/apt stable main" | sudo tee -a /etc/apt/sources.list.d/elastic-7.x.list
apt update
apt install elasticsearch

systemctl start elasticsearch
systemctl enable elasticsearch


############################
#
# Install Python with Tools
#
############################

# install pyenv for vagrant user
apt install -y make build-essential libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev wget curl llvm libncurses5-dev libncursesw5-dev xz-utils tk-dev libffi-dev liblzma-dev python-openssl
su - vagrant -c "curl https://pyenv.run | bash"

echo 'export PYENV_ROOT="$HOME/.pyenv"' >> /home/vagrant/.profile
echo 'export PATH="$PYENV_ROOT/bin:$PATH"' >> /home/vagrant/.profile
echo 'eval "$(pyenv init --path)"' >> /home/vagrant/.profile

echo 'export PATH="$HOME/.pyenv/bin:$PATH"' >> /home/vagrant/.bashrc
echo 'eval "$(pyenv init -)"' >> /home/vagrant/.bashrc
echo 'eval "$(pyenv virtualenv-init -)"' >> /home/vagrant/.bashrc

# install and use python 3.9.7
su - vagrant -c "/home/vagrant/.pyenv/bin/pyenv install 3.9.7"
su - vagrant -c "/home/vagrant/.pyenv/bin/pyenv global 3.9.7"

# install pipenv
su - vagrant -c "/home/vagrant/.pyenv/shims/pip install pipenv"


##################
#
# Install Ansible
#
##################

# install ansible for vagrant user
echo 'export PATH="$HOME/.local/bin:$PATH"' >> /home/vagrant/.bashrc
su - vagrant -c "curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py"
su - vagrant -c "~/.pyenv/shims/python get-pip.py --user"
su - vagrant -c "~/.pyenv/shims/pip install --user ansible"
mkdir -p /etc/ansible
cp /vagrant/provision/development/templates/etc/ansible/hosts /etc/ansible/hosts


################
#
# Install Nginx
#
################

apt install -y nginx
ufw allow 'Nginx Full'
systemctl enable nginx.service


##################
#
# Configure Nginx
#
##################

# symlink mapped application directory to operational /var subdirectory
mkdir -p /var/www/vhosts
ln -s /vagrant/application /var/www/vhosts/api.carevirtue.vm

# setup public API reverse proxy
cp /vagrant/provision/development/templates/etc/nginx/sites-available/api.carevirtue.vm.conf /etc/nginx/sites-available/api.carevirtue.vm.conf
ln -s /etc/nginx/sites-available/api.carevirtue.vm.conf /etc/nginx/sites-enabled/api.carevirtue.vm.conf

# setup admin API reverse proxy
cp /vagrant/provision/development/templates/etc/nginx/sites-available/api.admin.carevirtue.vm.conf /etc/nginx/sites-available/api.admin.carevirtue.vm.conf
ln -s /etc/nginx/sites-available/api.admin.carevirtue.vm.conf /etc/nginx/sites-enabled/api.admin.carevirtue.vm.conf

# restart nginx
systemctl restart nginx


##################
#
# Install Docker
#
##################

# setup docker registry
apt install -y  apt-transport-https ca-certificates curl gnupg-agent software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"

# install docker
apt update
apt install -y docker-ce docker-ce-cli containerd.io

# update permissions
usermod -aG docker vagrant

# install docker-compose
curl -L "https://github.com/docker/compose/releases/download/1.27.4/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose


######################
#
# Install Stripe CLI
#
######################

# download and install Stripe command line interface
curl -L https://github.com/stripe/stripe-cli/releases/download/v1.7.9/stripe_1.7.9_linux_x86_64.tar.gz -o /root/stripe_1.7.9_linux_x86_64.tar.gz
tar -xvf /root/stripe_1.7.9_linux_x86_64.tar.gz -C /root
mv /root/stripe /usr/local/bin/stripe


###############
#
# VIM Settings
#
###############

su vagrant <<EOSU
echo 'syntax enable
set hidden
set history=100
set number
filetype plugin indent on
set tabstop=4
set shiftwidth=4
set expandtab' > ~/.vimrc
EOSU
