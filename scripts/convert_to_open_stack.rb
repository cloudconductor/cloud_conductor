#!/bin/env ruby

require './src/helpers/loader'

if ARGV.size != 1
  puts 'bundle exec scripts/convert_to_open_stack.rb aws-template-file'
  exit 1
end

template = JSON.load(File.open(ARGV.first)).with_indifferent_access

converter = CloudConductor::Converters::OpenStackConverter.new
puts converter.convert(template, {}).to_json
