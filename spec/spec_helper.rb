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
require 'rubygems'
require 'spork'

Spork.prefork do
  require File.expand_path('../src/helpers/loader', File.dirname(__FILE__))
  Bundler.require(:development, :test)

  ActiveRecord::Base.establish_connection :test

  FactoryGirl.definition_file_paths = %w(./spec/factories)

  RSpec.configure do |config|
    # Enable focus feature to execute focused test only.
    config.filter_run focus: true
    config.run_all_when_everything_filtered = true

    config.before :all do
      FactoryGirl.find_definitions
      FactoryGirl.reload
    end

    config.before :suite do
      DatabaseCleaner.strategy = :transaction
      DatabaseCleaner.clean_with(:truncation)
    end

    config.around(:each) do |example|
      DatabaseCleaner.cleaning do
        example.run
      end
    end
  end
end

Spork.each_run do
end
