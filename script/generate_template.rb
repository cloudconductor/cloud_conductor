#!/bin/env ruby

require_relative '../lib/cloud_conductor/terraform'
require 'pry'

cloud = Cloud.new(name: 'aws', type: :aws)
patterns = []
patterns << Pattern.new(name: 'cloud_conductor_init',
                        url: 'https://github.com/cloudconductor/cloud_conductor_init',
                        revision: 'feature/terraform')
patterns << Pattern.new(name: 'tomcat_pattern',
                        url: 'https://github.com/cloudconductor-patterns/tomcat_pattern',
                        revision: 'feature/terraform')
patterns << Pattern.new(name: 'zabbix_pattern',
                        url: 'https://github.com/cloudconductor-patterns/zabbix_pattern',
                        revision: 'feature/terraform')

mappings = {
  cloud_conductor_init: {
    availability_zones: { type: :static, value: 'us-east-1a, us-east-1b' },
    subnet_size: { type: :static, value: 2 }
  },
  tomcat_pattern: {
    bootstrap_expect: { type: :variable, value: 'bootstrap_expect', default: '0' },
    vpc_id: { type: :module, value: 'cloud_conductor_init.vpc_id' },
    subnet_ids: { type: :module, value: 'cloud_conductor_init.subnet_ids' },
    shared_security_group: { type: :module, value: 'cloud_conductor_init.shared_security_group' },
    key_name: { type: :static, value: 'develop-key' },
    web_image: { type: :static, value: 'ami-c66326ac' },
    ap_image: { type: :static, value: 'ami-52602538' },
    db_image: { type: :static, value: 'ami-ea632680' },
    web_instance_type: { type: :static, value: 't2.micro' },
    ap_instance_type: { type: :static, value: 't2.micro' },
    db_instance_type: { type: :static, value: 't2.micro' },
    web_server_size: { type: :static, value: 1 },
    ap_server_size: { type: :static, value: 1 },
    db_server_size: { type: :static, value: 1 }
  },
  zabbix_pattern: {
    bootstrap_expect: { type: :variable, value: 'bootstrap_expect' },
    vpc_id: { type: :module, value: 'cloud_conductor_init.vpc_id' },
    subnet_ids: { type: :module, value: 'cloud_conductor_init.subnet_ids' },
    shared_security_group: { type: :module, value: 'cloud_conductor_init.shared_security_group' },
    key_name: { type: :static, value: 'develop-key' },
    monitoring_image: { type: :static, value: 'ami-8c6c29e6' },
    monitoring_instance_type: { type: :static, value: 't2.micro' },
    monitoring_server_size: { type: :static, value: 1 }
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
