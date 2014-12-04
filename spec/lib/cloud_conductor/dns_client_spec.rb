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
  describe DNSClient do
    let(:dns_client) do
      config = { service: 'route53', access_key: 'access_key', secret_key: 'secret_key', ttl: 60 }
      allow(CloudConductor::Config).to receive_message_chain(:dns, :configuration).and_return(config)
      DNSClient.new
    end

    describe '#initialize' do
      it 'store Route53Client in @client' do
        expect(dns_client.instance_variable_get(:@client)).to be_instance_of Route53Client
      end
      it 'store Bind9Client in @client' do
        config = { service: 'bind9', key_file: '/etc/testkey', server: 'test_dnsserver', ttl: 100 }
        allow(CloudConductor::Config).to receive_message_chain(:dns, :configuration).and_return(config)
        new_client = DNSClient.new
        expect(new_client.instance_variable_get(:@client)).to be_instance_of Bind9Client
      end
    end

    describe '#update' do
      it 'call @client.update' do
        expect(dns_client.instance_variable_get(:@client)).to receive(:update).with('www.example.com', '127.0.1.1')
        dns_client.update('www.example.com', '127.0.1.1')
      end
    end
  end

  describe Bind9Client do
    let(:bind9) do
      config = {
        key_file: '/etc/testkey',
        server: 'test_dnsserver',
        ttl: 100
      }
      Bind9Client.new(config)
    end

    describe '#update' do
      it 'update record' do
        allow(Open3).to receive(:capture3).and_return('out1', 'err1', 'nsupdate1')
        expect(Open3).to receive(:capture3).with(
          'sudo /usr/bin/nsupdate -k /etc/testkey',
          stdin_data: "server test_dnsserver\n" \
                      "update delete test_domain\n" \
                      "send\n" \
                      "update add test_domain 100 A 10.0.0.1\n" \
                      "send\n"
        )
        bind9.update 'test_domain', '10.0.0.1'
      end
    end
  end

  describe Route53Client do
    let(:route53) do
      config = {
        service: 'route53',
        access_key: 'access_key',
        secret_key: 'secret_key',
        ttl: 60
      }
      Route53Client.new(config)
    end

    let(:hosted_zone) do
      { name: 'example.com.', id: 'xxxxxxxx' }
    end

    let(:resource_record_set) do
      { name: 'www.example.com.', type: 'A' }
    end

    before do
      AWS.stub!
      resp = route53.instance_variable_get(:@client).stub_for(:list_hosted_zones)
      resp.data[:hosted_zones] = [hosted_zone]
      resp = route53.instance_variable_get(:@client).stub_for(:list_resource_record_sets)
      resp.data[:resource_record_sets] = [resource_record_set]
      resp.data[:is_truncated] = false
    end

    describe '#initialize' do
      it 'store @client when receive access_key and secret_key' do
        config = { service: 'route53', access_key: 'access_key', secret_key: 'secret_key' }
        result = Route53Client.new(config)
        expect(result.instance_variable_get(:@client)).to be_kind_of AWS::Route53::Client
      end
      it 'raise ArgumentError when do not receive access_key or secret_key' do
        config = { service: 'route53' }
        expect { Route53Client.new(config) }.to raise_error ArgumentError, 'Need access_key and secret_key to access AWS Route53'
      end
    end

    describe '#update' do
      it 'should success to update Route53 resource record set when receive existent record name' do
        result = route53.update('www.example.com', '127.0.1.1')
        expect(result).to be_truthy
      end
      it 'should success to create Route53 resource record set when receive non-existent record name' do
        allow(route53).to receive(:sleep)
        result = route53.update('www2.example.com', '127.0.2.1')
        expect(result).to be_truthy
      end
      it 'should fail to update Route53 resource record set when receive non-existent domain name' do
        error_message = "Cannot find AWS Route53 hosted zone to organize 'example.org'."
        expect { route53.update('www.example.org', '127.0.1.1') }.to raise_error RuntimeError, error_message
      end
    end

    describe '#find_hosted_zone' do
      it 'return hosted zone when receive existent domain name' do
        result = route53.send(:find_hosted_zone, 'example.com')
        expect(result).to be_instance_of Hash
        expect(result[:name]).to eq hosted_zone[:name]
        expect(result[:id]).to eq hosted_zone[:id]
      end
      it 'return nil when receive non-existent domain name' do
        result = route53.send(:find_hosted_zone, 'example.org')
        expect(result).to be_nil
      end
    end

    describe '#find_resource_record_set' do
      it 'return resource record set when receive existent record name and type' do
        result = route53.send(:find_resource_record_set, hosted_zone, 'www.example.com', 'A')
        expect(result).to be_instance_of Hash
        expect(result[:name]).to eq resource_record_set[:name]
        expect(result[:type]).to eq resource_record_set[:type]
      end
      it 'return nil when receive non-existent record name' do
        result = route53.send(:find_resource_record_set, hosted_zone, 'www2.example.com', 'A')
        expect(result).to be_nil
      end
    end

    describe '#create_or_update_resource_record_set' do
      it 'return true when success to update resource record set' do
        result = route53.send(:create_or_update_resource_record_set, hosted_zone, 'www.example.com', '127.0.1.1', 'UPSERT')
        expect(result).to be true
      end
      it 'return true when success to create resource record set' do
        result = route53.send(:create_or_update_resource_record_set, hosted_zone, 'www2.example.com', '127.0.2.1', 'CREATE')
        expect(result).to be true
      end
      it 'return false when raise error' do
        resp = route53.instance_variable_get(:@client).stub_for(:change_resource_record_sets)
        resp.error = 'Something wrong'
        result = route53.send(:create_or_update_resource_record_set, hosted_zone, 'www.example.org', '127.0.1.1', 'UPSERT')
        expect(result).to be false
      end
    end

    describe '#log_response' do
      it 'send log message to logger' do
        expect(Log).to receive(:debug).at_least(2).times
        response = route53.instance_variable_get(:@client).stub_for(:list_hosted_zones)
        route53.send(:log_response, response)
      end
    end

    describe '#log_error' do
      it 'send log message to logger' do
        expect(Log).to receive(:error)
        expect(Log).to receive(:debug)
        method_name = :list_resource_record_sets
        options = { hosted_zone_id: 'XXXXXX' }
        exception = AWS::Route53::Errors::NoSuchHostedZone.new("No hosted zone found with ID: #{options[:hosted_zone_id]}")
        route53.send(:log_error, exception, method_name, options)
      end
    end
  end
end
