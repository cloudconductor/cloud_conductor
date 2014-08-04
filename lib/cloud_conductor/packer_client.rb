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
module CloudConductor
  class PackerClient
    def initialize(options)
      @packer_path = options[:packer_path]
      @packer_json_path = options[:packer_json_path]
      @vars = options.except(:packer_path, :packer_json_path)
    end

    def build(repository_url, revision, clouds, oss, role)
      only = (clouds.product oss).map { |cloud, os| "#{cloud}-#{os}" }.join(',')
      @vars.update(repository_url: repository_url)
      @vars.update(revision: revision)
      vars_text = @vars.map { |key, value| "-var '#{key}=#{value}'" }.join(' ')
      command = "#{@packer_path} build #{vars_text} -var 'role=#{role}' -only=#{only} #{@packer_json_path}"
      status, stdout, stderr = systemu(command)

      yield status, stdout, stderr if block_given?
    end
  end
end
