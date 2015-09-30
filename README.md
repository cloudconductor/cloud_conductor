About
=====

CloudConductor is hybrid cloud management and deployment tool.
It targets to enable transparent management of multiple cloud environment
and self-directive operation.

For more information, please visit [official web site](http://cloudconductor.org/).


Requirements
============

System Requirements
-------------------

- OS: Red Hat Enterprise Linux 6.5 or CentOS 6.5

Prerequisites
-------------

- git
- sqlite-devel (or other database software)
- ruby (>= 2.1.2)
- rubygems
- bundler


Quick Start
===========

### Clone github repository

```bash
git clone https://github.com/cloudconductor/cloud_conductor.git
```

### Install dependencies and initialize database

Install required modules or packages to build CloudConductor

```bash
sudo yum -y update
sudo yum -y install git wget unzip gcc gcc-c++ make openssl-devel libxslt-devel libxml2-devel
```

Install Packer (Please replace amd64 to 386 in case of working on 32bit operating systems)

```bash
sudo mkdir /opt/packer
wget https://dl.bintray.com/mitchellh/packer/packer_0.8.6_linux_amd64.zip
sudo unzip packer_0.8.6_linux_amd64.zip -d /opt/packer
```

Clone repository

```bash
git clone https://github.com/cloudconductor/cloud_conductor.git
```

Install required gems

```bash
cd cloud_conductor
bundle install
```

Initialize configurations and database

```bash
cp config/config.rb.smp config/config.rb
vi config/config.rb
----------
Edit configurations below.
  cloudconductor.url
  dns.service
  dns.access_key, dns.secret_key or dns.server, dns.key_file
  zabbix.url
  zabbix.user
  zabbix.password
  zabbix.default_template_name

Please see Getting Started in CloudConductor Official Website.
----------
secret_key_base=$(bundle exec rake secret)
sed -i -e "s/secret_key_base: .*/secret_key_base: ${secret_key_base}/g" config/secrets.yml
sed -i -e "s/# config.secret_key = '.*'/config.secret_key = '${secret_key_base}'/" config/initializers/devise.rb
bundle exec rake db:migrate RAILS_ENV=production
bundle exec rake register:admin RAILS_ENV=production
  Input administrator account information.
    Email: <your_email_address>
    Name: <user_name>
    Password: <password>
    Password Confirmation: <password>
```

### Run server

```bash
bundle exec unicorn -c config/unicorn.rb -E production -D
```

### Stop server

```bash
kill -QUIT `cat ./unicorn.pid`
```

Copyright and License
=====================

Copyright 2014, 2015 TIS inc.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.


Contact
========

For more information: <http://cloudconductor.org/>

Report issues and requests: <https://github.com/cloudconductor/cloud_conductor/issues>

Send feedback to: <ccndctr@gmail.com>
