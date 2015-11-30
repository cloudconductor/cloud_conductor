#!/bin/env ruby

require_relative '../lib/cloud_conductor/terraform'
require 'pry'

cloud = Cloud.new(name: 'aws', type: :aws)
patterns = []
patterns << Pattern.new(name: 'cloud_conductor_init',
                        url: 'https://github.com/cloudconductor/cloud_conductor_init',
                        revision: 'test/terraform')
patterns << Pattern.new(name: 'tomcat_pattern',
                        url: 'https://github.com/cloudconductor-patterns/tomcat_pattern',
                        revision: 'test/terraform')
patterns << Pattern.new(name: 'zabbix_pattern',
                        url: 'https://github.com/cloudconductor-patterns/zabbix_pattern',
                        revision: 'test/terraform')

mappings = {
  cloud_conductor_init: {
    availability_zones: { type: :value, value: 'us-east-1a, us-east-1b' },
    subnet_size: { type: :value, value: 2 }
  },
  tomcat_pattern: {
    bootstrap_expect: { type: :variable, value: 'bootstrap_expect', default: '0' },
    vpc_id: { type: :module, value: 'cloud_conductor_init.vpc_id' },
    subnet_id: { type: :module, value: 'cloud_conductor_init.subnet_id' },
    shared_security_group: { type: :module, value: 'cloud_conductor_init.shared_security_group' },
    key_name: { type: :value, value: 'develop-key' },
    web_image: { type: :value, value: 'ami-c66326ac' },
    ap_image: { type: :value, value: 'ami-52602538' },
    db_image: { type: :value, value: 'ami-ea632680' },
    web_instance_type: { type: :value, value: 't2.micro' },
    ap_instance_type: { type: :value, value: 't2.micro' },
    db_instance_type: { type: :value, value: 't2.micro' },
    web_server_size: { type: :value, value: 1 },
    ap_server_size: { type: :value, value: 1 },
    db_server_size: { type: :value, value: 1 }
  },
  zabbix_pattern: {
    bootstrap_expect: { type: :variable, value: 'bootstrap_expect' },
    vpc_id: { type: :module, value: 'cloud_conductor_init.vpc_id' },
    subnet_id: { type: :module, value: 'cloud_conductor_init.subnet_id' },
    shared_security_group: { type: :module, value: 'cloud_conductor_init.shared_security_group' },
    key_name: { type: :value, value: 'develop-key' },
    monitoring_image: { type: :value, value: 'ami-8c6c29e6' },
    monitoring_instance_type: { type: :value, value: 't2.micro' },
    monitoring_server_size: { type: :value, value: 1 }
  }
}.with_indifferent_access

parent = CloudConductor::Terraform::Parent.new(cloud)
patterns.each do |pattern|
  parent.modules << CloudConductor::Terraform::Module.new(cloud, pattern, mappings[pattern.name])
end

temporary_directory = 'tmp/terraform'
FileUtils.mkdir_p temporary_directory unless Dir.exist?(temporary_directory)
parent.save("#{temporary_directory}/main.tf")
# parent.cleanup()
