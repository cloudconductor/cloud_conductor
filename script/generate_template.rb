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

parent = CloudConductor::Terraform::Parent.new
patterns.each do |pattern|
  parent.modules[pattern.name] = CloudConductor::Terraform::Module.new(pattern, cloud)
end

parent.resolve_dependencies
parent.save('../tmp/main.tf')
# template.cleanup()
