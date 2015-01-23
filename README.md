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
yum -y update
yum -y install gcc gcc-c++ make openssl-devel libxslt-devel libxml2-devel wget unzip
```

Install Packer (Please replace amd64 to 386 in case of working on 32bit operating systems)

```bash
mkdir /opt/packer
wget https://dl.bintray.com/mitchellh/packer/packer_0.7.1_linux_amd64.zip
unzip packer_0.7.1_linux_amd64.zip -d /opt/packer
```

Clone repository

```bash
git clone https://github.com/cloudconductor/cloud_conductor.git
```

Install required gems

```bash
gem install bundler
cd cloud_conductor
bundle install
```

Initialize configurations and database

```bash
$ cp config/config.rb.smp config/config.rb
$ vi config/config.rb
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
$ bundle exec rake db:migrate RAILS_ENV=production
$ bundle exec rake db:seed RAILS_ENV=production
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

Copyright 2014 TIS inc.

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
