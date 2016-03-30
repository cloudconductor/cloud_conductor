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

- OS: Red Hat Enterprise Linux or CentOS (6.5 or later and 7.x)

Prerequisites
-------------

- git
- ruby (>= 2.1.2)
- rubygems
- bundler
- PostgreSQL (9.4 or later)


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
wget https://releases.hashicorp.com/packer/0.9.0/packer_0.9.0_linux_amd64.zip
sudo unzip packer_0.9.0_linux_amd64.zip -d /opt/packer
```

Install Terraform

```bash
sudo mkdir /opt/terraform
wget https://releases.hashicorp.com/terraform/0.6.13/terraform_0.6.13_linux_amd64.zip
sudo unzip terraform_0.6.13_linux_amd64.zip -d /opt/terraform
```

Clone repository

```bash
git clone https://github.com/cloudconductor/cloud_conductor.git
```

Checkout submodules

```bash
cd cloud_conductor
git submodule update --init
```

Install required gems

```bash
bundle install
```

Initialize configurations and database

```bash
cp config/config.rb.smp config/config.rb
vi config/config.rb
----------
Edit configurations below.
  dns.service
  dns.access_key, dns.secret_key or dns.server, dns.key_file

----------
cp config/database.yml.smp config/database.yml
vi config/database.yml
----------
Edit configurations below.
  username
  password

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

Please see [Getting Started](http://cloudconductor.org/documents/getting-started) in [CloudConductor Official Website](http://cloudconductor.org) for more information.

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

Copyright 2014-2016 TIS inc.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.


Libraries We Use
=====================
* ruby-hcl https://github.com/sikula/ruby-hcl
 * Copyright (c) 2015 sikula under the ([MIT LICENCE](https://raw.githubusercontent.com/sikula/ruby-hcl/f143e20b1d5ed04bac03a363d472508d0f556a83/LICENSE))

Contact
========

For more information: <http://cloudconductor.org/>

Report issues and requests: <https://github.com/cloudconductor/cloud_conductor/issues>

Send feedback to: <ccndctr@gmail.com>
