#!/bin/env ruby

# -*- coding: utf-8 -*-
# Copyright 2014 TIS Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
require 'optparse'
require File.expand_path('../src/helpers/loader', File.dirname(__FILE__))

options = { count: Float::INFINITY, wait: 10, daemon: false }

parser = OptionParser.new
parser.on('-c count', '--count count')  { |v| options[:count] = v.to_i }
parser.on('-w second', '--wait second') { |v| options[:wait] = v.to_i }
parser.on('-d', '--daemon')             { |v| options[:daemon] = true }

parser.parse!(ARGV)

Process.daemon if options[:daemon]

1.upto(options[:count]) do |n|
  sleep options[:wait] unless n == 1
  CloudConductor::StackObserver.new.update
end
