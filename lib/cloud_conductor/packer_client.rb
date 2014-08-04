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

    private

    def parse(stdout)
      # success
      # {
      #   'aws-centos' => {
      #     status: :success,
      #     image: 'ami-e18bd5e0'
      #   },
      #   'openstack-centos' => {
      #     status: :success,
      #     image: '78dd03a1-c9c2-4376-bae9-b84c7b0ca6e1'
      #   }
      # }

      # error_aws_image_not_found
      # {
      #   'aws-centos' => {
      #     status: :error,
      #     message: "Error querying AMI: The image id '[ami-29dc9229]' does not exist (InvalidAMIID.NotFound)"
      #   }
      # }

      # error_aws_ssh_faild
      # {
      #   'aws-centos' => {
      #     status: :error,
      #     message: 'Error waiting for SSH: ssh: handshake failed: ssh: unable to authenticate, attempted methods [none publickey], no supported methods remain'
      #   }
      # }

      # error_aws_provisioners_faild
      # {
      #   'aws-centos' => {
      #     status: :error,
      #     message: 'Script exited with non-zero exit status: 1'
      #   }
      # }

      # error_openstack_image_not_found
      # {
      #   'openstack-centos' => {
      #     status: :error,
      #     message: 'Error launching source server: Expected HTTP response code [202] when accessing URL(http://10.255.197.109:8774/v2/41acd44fb80544d39792509881c00724/servers); got 400 instead with the following body:\n==> openstack-centos: {"badRequest": {"message": "Invalid imageRef provided.", "code": 400}}'
      #   }
      # }

      # error_openstack_ssh_faild
      # {
      #   'openstack-centos' => {
      #     status: :error,
      #     message: 'Error waiting for SSH: ssh: handshake failed: ssh: unable to authenticate, attempted methods [none publickey], no supported methods remain'
      #   }
      # }

      # error_openstack_provisioners_faild
      # {
      #   'openstack-centos' => {
      #     status: :error,
      #     message: 'Script exited with non-zero exit status: 1'
      #   }
      # }

      # error_concurrency
      # {
      #   'aws-centos' => {
      #     status: :error,
      #     message: 'Script exited with non-zero exit status: 1'
      #   },
      #   'openstack-centos' => {
      #     status: :error,
      #     message: 'Script exited with non-zero exit status: 1'
      #   }
      # }
    end
  end
end
