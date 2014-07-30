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
    describe AddCrontabCFNPushStats do
      before do
        @patch = AddCrontabCFNPushStats.new

        @template = JSON.parse <<-EOS
          {
            "Resources": {
              "Sample": {
                "Type": "AWS::EC2::RouteTable",
                "Properties": {
                  "VpcId": { "Ref": "VPC" }
                }
              },
              "LaunchConfigA": {
                "Type": "AWS::AutoScaling::LaunchConfiguration",
                "Metadata" : {
                  "Comment": "Launch instance from AMI",
                  "AWS::CloudFormation::Init": {
                    "config": {
                    }
                  }
                },
                "Properties": {
                  "UserData": {
                    "Fn::Base64": ""
                  }
                }
              },
              "LaunchConfigB": {
                "Type": "AWS::AutoScaling::LaunchConfiguration",
                "Metadata" : {
                  "Comment": "Launch instance from AMI",
                  "AWS::CloudFormation::Init": {
                    "config": {
                    }
                  }
                },
                "Properties": {
                  "UserData": {
                    "Fn::Base64": {
                      "Fn::Join": ["", "#!/bin/bash\\n"]
                    }
                  }
                }
              },
              "AlarmToScaleupA": {
                "Type": "AWS::CloudWatch::Alarm",
                "Properties": {
                  "AlarmDescription": "Restart the Server if status check fails >= 3 times in 10 minutes",
                  "MetricName": "CPUUtilization",
                  "Namespace": "system/linux",
                  "Dimensions": [
                    {
                      "Name": "AutoScalingGroupName"
                    },
                    {
                      "Name": "AutoScalingGroupName",
                      "Value": { "Ref": "NotAutoScaling" }
                    },
                    {
                      "Name": "AutoScalingGroupName",
                      "Value": { "Ref": "AutoScalingA" }
                    },
                    {
                      "Name": "AutoScalingGroupName",
                      "Value": "InstanceId"
                    }
                  ],
                  "Statistic": "Average",
                  "Period": "60",
                  "EvaluationPeriods": "1",
                  "Threshold": "60",
                  "AlarmActions": [ { "Ref": "ScaleUp" } ],
                  "ComparisonOperator": "GreaterThanThreshold"
                }
              },
              "AlarmToScaleupB": {
                "Type": "AWS::CloudWatch::Alarm",
                "Properties": {
                  "AlarmDescription": "Restart the Server if status check fails >= 3 times in 10 minutes",
                  "MetricName": "CPUUtilization",
                  "Namespace": "system/linux",
                  "Dimensions": [
                    {
                      "Name": "AutoScalingGroupName",
                      "Value": { "Ref": "AutoScalingB" }
                    }
                  ],
                  "Statistic": "Average",
                  "Period": "60",
                  "EvaluationPeriods": "1",
                  "Threshold": "60",
                  "AlarmActions": [ { "Ref": "ScaleUp" } ],
                  "ComparisonOperator": "GreaterThanThreshold"
                }
              },
              "AutoScalingA": {
                "DependsOn" : [ "Subnet1A" ],
                "Type" : "AWS::AutoScaling::AutoScalingGroup",
                "Properties" : {
                  "LaunchConfigurationName": { "Ref": "LaunchConfigA" }
                }
              },
              "AutoScalingB": {
                "DependsOn" : [ "Subnet1A" ],
                "Type" : "AWS::AutoScaling::AutoScalingGroup",
                "Properties" : {
                  "LaunchConfigurationName": { "Ref": "LaunchConfigB" }
                }
              }
            }
          }
        EOS

        @template = @template.with_indifferent_access
      end

      it 'extend Patch class' do
        expect(AddCrontabCFNPushStats.superclass).to eq(Patch)
      end

      describe '#need?' do
        it 'return false when template hasn\'t Resources hash' do
          expect(@patch.need?({}, {})).to be_falsey
        end

        it 'return false when template hasn\'t Alarm Resource' do
          @template[:Resources].except!(:AlarmToScaleupA, :AlarmToScaleupB)
          expect(@patch.need?(@template, {})).to be_falsey
        end

        it 'return false when Alarm Resource not linked AutoScaling' do
          @template[:Resources][:AlarmToScaleupA][:Properties][:Dimensions][2][:Value].except!(:Ref)
          @template[:Resources][:AlarmToScaleupB][:Properties][:Dimensions][0][:Value].except!(:Ref)
          expect(@patch.need?(@template, {})).to be_falsey
        end

        it 'return true when template has LaunchConfiguration Resource' do
          expect(@patch.need?(@template, {})).to be_truthy
        end
      end

      describe '#ensure' do
        it 'construct Hashes to files' do
          template = JSON.parse <<-EOS
            {
              "Resources": {
                "LaunchConfigA": {
                  "Type": "AWS::AutoScaling::LaunchConfiguration",
                  "Properties": {}
                },
                "LaunchConfigB": {
                  "Type": "AWS::AutoScaling::LaunchConfiguration",
                  "Properties": {}
                }
              }
            }
          EOS
          result = @patch.ensure(template.with_indifferent_access, {})
          expect(result[:Resources][:LaunchConfigA][:Metadata]).to be_is_a Hash
          expect(result[:Resources][:LaunchConfigA][:Metadata]['AWS::CloudFormation::Init']).to be_is_a Hash
          expect(result[:Resources][:LaunchConfigA][:Metadata]['AWS::CloudFormation::Init'][:config]).to be_is_a Hash
          expect(result[:Resources][:LaunchConfigB][:Metadata]).to be_is_a Hash
          expect(result[:Resources][:LaunchConfigB][:Metadata]['AWS::CloudFormation::Init']).to be_is_a Hash
          expect(result[:Resources][:LaunchConfigB][:Metadata]['AWS::CloudFormation::Init'][:config]).to be_is_a Hash
        end
      end

      describe '#apply' do
        it 'add /tmp/crontab-cfn-push-stats resource' do
          template_config = @template[:Resources][:LaunchConfigA][:Metadata]['AWS::CloudFormation::Init'][:config]
          expect(template_config.size).to eq(0)
          expect(template_config['/tmp/crontab-cfn-push-stats']).to be_nil
          result = @patch.apply @template, {}
          result_config = result[:Resources][:LaunchConfigA][:Metadata]['AWS::CloudFormation::Init'][:config]
          expect(result_config.size).to eq(1)
          expect(result_config['/tmp/crontab-cfn-push-stats']).not_to be_nil
        end

        it 'add only one /tmp/crontab-cfn-push-stats resource' do
          result = @patch.apply @template, {}
          result = @patch.apply result, {}
          result_config = result[:Resources][:LaunchConfigA][:Metadata]['AWS::CloudFormation::Init'][:config]
          expect(result_config.size).to eq(1)
        end

        it 'add Alarm to /tmp/crontab-cfn-push-stats:content property' do
          result = @patch.apply @template, {}
          result_config = result[:Resources][:LaunchConfigA][:Metadata]['AWS::CloudFormation::Init'][:config]
          expect(result_config['/tmp/crontab-cfn-push-stats'][:content]['Fn::Join'][1][1][:Ref]).to eq('AlarmToScaleupA')
        end

        it 'add 3 row UserData when Fn::Base64 is empty string' do
          result = @patch.apply @template, {}
          lines = result[:Resources][:LaunchConfigA][:Properties][:UserData]['Fn::Base64'].split("\n")
          expect(lines.size).to eq(3)
          expect(lines[0]).to eq('#!/bin/bash')
          expect(lines[1]).to eq('# push stats periodically by cron')
          expect(lines[2]).to eq('crontab /tmp/crontab-cfn-push-stats')
        end

        it 'add 2 row UserData when Fn::Base64 isn\'t empty string' do
          @template[:Resources][:LaunchConfigA][:Properties][:UserData]['Fn::Base64'] = "#!/bin/bash\n"
          result = @patch.apply @template, {}
          lines = result[:Resources][:LaunchConfigA][:Properties][:UserData]['Fn::Base64'].split("\n")
          expect(lines.size).to eq(3)
          expect(lines[0]).to eq('#!/bin/bash')
          expect(lines[1]).to eq('# push stats periodically by cron')
          expect(lines[2]).to eq('crontab /tmp/crontab-cfn-push-stats')
        end

        it 'add 2 row UserData when Fn::Base64 is hash' do
          result = @patch.apply @template, {}
          lines = result[:Resources][:LaunchConfigB][:Properties][:UserData]['Fn::Base64']['Fn::Join'][1].split("\n")
          expect(lines.size).to eq(3)
          expect(lines[0]).to eq('#!/bin/bash')
          expect(lines[1]).to eq('# push stats periodically by cron')
          expect(lines[2]).to eq('crontab /tmp/crontab-cfn-push-stats')
        end

        it 'doesn\'t affect to other resources' do
          original = @template[:Resources][:Sample].deep_dup

          expect(@template[:Resources][:Sample]).to eq(original)
          result = @patch.apply @template, {}
          expect(result[:Resources][:Sample]).to eq(original)
        end

        it 'doesn\'t affect to source template' do
          original_template = @template.deep_dup

          expect(original_template).to eq(@template)
          @patch.apply @template, {}
          expect(original_template).to eq(@template)
        end
      end
    end
  end
end
