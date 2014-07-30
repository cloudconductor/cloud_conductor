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
  module Patches
    class AddCrontabCFNPushStats < Patch
      include PatchUtils

      JSON_TEMPLATE = <<-EOS
        {
          "/tmp/crontab-cfn-push-stats" : {
            "content" : { "Fn::Join" : [""]},
            "mode"    : "000600",
            "owner"   : "root",
            "group"   : "root"
          }
        }
      EOS

      def initialize
      end

      def need?(template, _parameters)
        return false unless template[:Resources]
        alarm = template[:Resources].select(&type?('AWS::CloudWatch::Alarm'))
        contains_ref(alarm, template[:Resources].select(&type?('AWS::AutoScaling::AutoScalingGroup')).keys)
      end

      def ensure(template, _parameters)
        template[:Resources] ||= {}
        template[:Resources].select(&type?('AWS::AutoScaling::LaunchConfiguration')).keys.each do |key|
          template[:Resources][key] ||= {}
          template[:Resources][key][:Metadata] ||= {}
          template[:Resources][key][:Metadata]['AWS::CloudFormation::Init'] ||= {}
          template[:Resources][key][:Metadata]['AWS::CloudFormation::Init'][:config] ||= {}
          template[:Resources][key][:Properties][:UserData] ||= {}
          template[:Resources][key][:Properties][:UserData]['Fn::Base64'] ||= ''
        end
        template
      end

      def apply(template, _parameters)
        template = template.deep_dup
        template = apply_files(template)
        template = apply_user_data(template)

        template
      end

      def apply_files(template)
        template[:Resources].select(&type?('AWS::AutoScaling::LaunchConfiguration')).each do |launch_config, resource|
          auto_scaling_groups = template[:Resources].select(&type?('AWS::AutoScaling::AutoScalingGroup')).select(&dependent?([launch_config]))

          alarms = template[:Resources].select(&type?('AWS::CloudWatch::Alarm')).select(&dependent?(auto_scaling_groups.keys))

          contents = alarms.map do |alarm, _resource|
            ['* * * * * /usr/bin/cfn-push-stats --cpu-util --watch ', { Ref: alarm }, '\n']
          end

          crontab_cfn_push_stats = JSON.parse JSON_TEMPLATE
          crontab_cfn_push_stats['/tmp/crontab-cfn-push-stats']['content']['Fn::Join'] << contents.flatten

          resource[:Metadata]['AWS::CloudFormation::Init'][:config].update crontab_cfn_push_stats
        end

        template
      end

      def apply_user_data(template)
        template[:Resources].select(&type?('AWS::AutoScaling::LaunchConfiguration')).each do |_launch_config, resource|
          user_data = resource[:Properties][:UserData]['Fn::Base64']
          target = user_data if user_data.is_a?(String)
          target = user_data['Fn::Join'][1] if user_data.is_a?(Hash)

          target << "#!/bin/bash\n" if target.empty?
          target << "# push stats periodically by cron\n"
          target << "crontab /tmp/crontab-cfn-push-stats\n"
        end

        template
      end

      def dependent?(keys)
        ->(_, resource) { contains_ref(resource, keys) }
      end
    end
  end
end
