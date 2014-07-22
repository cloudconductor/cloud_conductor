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
  module Converters
    # rubocop:disable ClassLength
    class OpenStackConverter < Converter
      # rubocop:disable MethodLength
      def initialize
        super

        # Remove unimplemented properties
        remove_auto_scaling_group_properties
        remove_launch_configuration_properties
        remove_instance_properties
        remove_network_interface_properties
        remove_vpc_properties
        remove_vpc_gateway_attachment_properties
        remove_load_balancer_properties
        remove_access_key_properties

        add_patch Patches::RemoveResource.new 'AWS::AutoScaling::ScheduledAction'
        add_patch Patches::RemoveResource.new 'AWS::CloudFormation::Authentication'
        add_patch Patches::RemoveResource.new 'AWS::CloudFormation::CustomResource'
        add_patch Patches::RemoveResource.new 'AWS::CloudFormation::Init'
        add_patch Patches::RemoveResource.new 'AWS::CloudFront::Distribution'
        add_patch Patches::RemoveResource.new 'AWS::CloudTrail::Trail'
        add_patch Patches::RemoveResource.new 'AWS::CloudWatch::Alarm'
        add_patch Patches::RemoveResource.new 'AWS::DynamoDB::Table'
        add_patch Patches::RemoveResource.new 'AWS::EC2::CustomerGateway'
        add_patch Patches::RemoveResource.new 'AWS::EC2::DHCPOptions'
        add_patch Patches::RemoveResource.new 'AWS::EC2::NetworkAcl'
        add_patch Patches::RemoveResource.new 'AWS::EC2::NetworkAclEntry'
        add_patch Patches::RemoveResource.new 'AWS::EC2::NetworkInterfaceAttachment'
        add_patch Patches::RemoveResource.new 'AWS::EC2::Route'
        add_patch Patches::RemoveResource.new 'AWS::EC2::SecurityGroupEgress'
        add_patch Patches::RemoveResource.new 'AWS::EC2::SecurityGroupIngress'
        add_patch Patches::RemoveResource.new 'AWS::EC2::SubnetNetworkAclAssociation'
        add_patch Patches::RemoveResource.new 'AWS::EC2::VPCDHCPOptionsAssociation'
        add_patch Patches::RemoveResource.new 'AWS::EC2::VPCPeeringConnection'
        add_patch Patches::RemoveResource.new 'AWS::EC2::VPNConnection'
        add_patch Patches::RemoveResource.new 'AWS::EC2::VPNConnectionRoute'
        add_patch Patches::RemoveResource.new 'AWS::EC2::VPNGateway'
        add_patch Patches::RemoveResource.new 'AWS::EC2::VPNGatewayRoutePropagation'
        add_patch Patches::RemoveResource.new 'AWS::ElastiCache::CacheCluster'
        add_patch Patches::RemoveResource.new 'AWS::ElastiCache::ParameterGroup'
        add_patch Patches::RemoveResource.new 'AWS::ElastiCache::SecurityGroup'
        add_patch Patches::RemoveResource.new 'AWS::ElastiCache::SecurityGroupIngress'
        add_patch Patches::RemoveResource.new 'AWS::ElastiCache::SubnetGroup'
        add_patch Patches::RemoveResource.new 'AWS::ElasticBeanstalk::Application'
        add_patch Patches::RemoveResource.new 'AWS::ElasticBeanstalk::ApplicationVersion'
        add_patch Patches::RemoveResource.new 'AWS::ElasticBeanstalk::ConfigurationTemplate'
        add_patch Patches::RemoveResource.new 'AWS::ElasticBeanstalk::Environment'
        add_patch Patches::RemoveResource.new 'AWS::IAM::Group'
        add_patch Patches::RemoveResource.new 'AWS::IAM::InstanceProfile'
        add_patch Patches::RemoveResource.new 'AWS::IAM::Policy'
        add_patch Patches::RemoveResource.new 'AWS::IAM::Role'
        add_patch Patches::RemoveResource.new 'AWS::IAM::UserToGroupAddition'
        add_patch Patches::RemoveResource.new 'AWS::Kinesis::Stream'
        add_patch Patches::RemoveResource.new 'AWS::Logs::LogGroup'
        add_patch Patches::RemoveResource.new 'AWS::Logs::MetricFilter'
        add_patch Patches::RemoveResource.new 'AWS::OpsWorks::App'
        add_patch Patches::RemoveResource.new 'AWS::OpsWorks::ElasticLoadBalancerAttachment'
        add_patch Patches::RemoveResource.new 'AWS::OpsWorks::Instance'
        add_patch Patches::RemoveResource.new 'AWS::OpsWorks::Layer'
        add_patch Patches::RemoveResource.new 'AWS::OpsWorks::Stack'
        add_patch Patches::RemoveResource.new 'AWS::Redshift::Cluster'
        add_patch Patches::RemoveResource.new 'AWS::Redshift::ClusterParameterGroup'
        add_patch Patches::RemoveResource.new 'AWS::Redshift::ClusterSecurityGroup'
        add_patch Patches::RemoveResource.new 'AWS::Redshift::ClusterSecurityGroupIngress'
        add_patch Patches::RemoveResource.new 'AWS::Redshift::ClusterSubnetGroup'
        add_patch Patches::RemoveResource.new 'AWS::RDS::DBParameterGroup'
        add_patch Patches::RemoveResource.new 'AWS::RDS::DBSubnetGroup'
        add_patch Patches::RemoveResource.new 'AWS::RDS::DBSecurityGroup'
        add_patch Patches::RemoveResource.new 'AWS::RDS::DBSecurityGroupIngress'
        add_patch Patches::RemoveResource.new 'AWS::Route53::RecordSet'
        add_patch Patches::RemoveResource.new 'AWS::Route53::RecordSetGroup'
        add_patch Patches::RemoveResource.new 'AWS::S3::BucketPolicy'
        add_patch Patches::RemoveResource.new 'AWS::SDB::Domain'
        add_patch Patches::RemoveResource.new 'AWS::SNS::Topic'
        add_patch Patches::RemoveResource.new 'AWS::SNS::TopicPolicy'
        add_patch Patches::RemoveResource.new 'AWS::SQS::Queue'
        add_patch Patches::RemoveResource.new 'AWS::SQS::QueuePolicy'

        add_patch Patches::RemoveMultipleSubnet.new
        add_patch Patches::AddIAMUser.new
        add_patch Patches::AddIAMAccessKey.new
        add_patch Patches::AddCFNCredentials.new
      end

      # Remove unimplemented properties from AutoScalingGroup
      def remove_auto_scaling_group_properties
        properties = []
        properties << :AvailabilityZones
        properties << :HealthCheckGracePeriod
        properties << :HealthCheckType
        add_patch Patches::RemoveProperty.new 'AWS::AutoScaling::AutoScalingGroup', properties
      end

      # Remove unimplemented properties from LaunchConfiguration
      def remove_launch_configuration_properties
        properties = []
        properties << :BlockDeviceMappings
        properties << :KernelId
        properties << :RamDiskId
        add_patch Patches::RemoveProperty.new 'AWS::AutoScaling::LaunchConfiguration', properties
      end

      # Remove unimplemented properties from Instance
      def remove_instance_properties
        properties = []
        properties << :DisableApiTermination
        properties << :KernelId
        properties << :Monitoring
        properties << :PlacementGroupName
        properties << :PrivateIpAddress
        properties << :RamDiskId
        properties << :SourceDestCheck
        properties << :Tenancy
        add_patch Patches::RemoveProperty.new 'AWS::EC2::Instance', properties
      end

      # Remove unimplemented properties from NetworkInterface
      def remove_network_interface_properties
        properties = []
        properties << :SourceDestCheck
        add_patch Patches::RemoveProperty.new 'AWS::EC2::NetworkInterface', properties
      end

      # Remove unimplemented properties from VPC
      def remove_vpc_properties
        properties = []
        properties << :InstanceTenancy
        add_patch Patches::RemoveProperty.new 'AWS::EC2::VPC', properties
      end

      # Remove unimplemented properties from VPCGatewayAttachment
      def remove_vpc_gateway_attachment_properties
        properties = []
        properties << :VpnGatewayId
        add_patch Patches::RemoveProperty.new 'AWS::EC2::VPCGatewayAttachment', properties
      end

      # Remove unimplemented properties from LoadBalancer
      def remove_load_balancer_properties
        properties = []
        properties << :AppCookieStickinessPolicy
        properties << :LBCookieStickinessPolicy
        properties << :SecurityGroups
        properties << :Subnets
        add_patch Patches::RemoveProperty.new 'AWS::ElasticLoadBalancing::LoadBalancer', properties
      end

      # Remove unimplemented properties from AccessKey
      def remove_access_key_properties
        properties = []
        properties << :Serial
        properties << :Status
        add_patch Patches::RemoveProperty.new 'AWS::IAM::AccessKey', properties
      end

      # Remove unimplemented properties from User
      def remove_user_properties
        properties = []
        properties << :Groups
        properties << :Path
        add_patch Patches::RemoveProperty.new 'AWS::IAM::User', properties
      end
    end
  end
end
