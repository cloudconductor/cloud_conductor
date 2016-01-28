require 'consul/client/catalog'
module Consul
  class Client
    describe Catalog do
      before do
        @stubs = Faraday::Adapter::Test::Stubs.new

        original_method = Faraday.method(:new)
        allow(Faraday).to receive(:new) do |*args, &block|
          original_method.call(*args) do |builder|
            builder.adapter :test, @stubs
            yield block if block
          end
        end

        @faraday = Faraday.new('http://localhost/v1')
        @client = Catalog.new @faraday
      end

      describe '#nodes' do
        def add_stub(path, value)
          encoded_value = Base64.encode64(value).chomp
          body = %([{"CreateIndex":5158,"ModifyIndex":5158,"LockIndex":0,"Key":"hoge","Flags":0,"Value":"#{encoded_value}"}])
          @stubs.get(path) { [200, {}, body] }
        end

        before do
          allow(@client).to receive(:sequential_try).and_yield(@faraday)
        end

        it 'delegate retry logic to #sequential_try' do
          expect(@client).to receive(:sequential_try)

          @stubs.get('/v1/catalog/nodes') { [200, {}, '[]'] }
          @client.nodes
        end

        it 'return empty array if response is empty' do
          @stubs.get('/v1/catalog/nodes') { [200, {}, '[]'] }
          nodes = @client.nodes
          expect(nodes).to be_is_a Array
          expect(nodes).to be_empty
        end

        it 'return array contains node and address' do
          json = <<-EOS
            [
              {
                "Node": "dummy1",
                "Address": "10.0.1.1"
              },
              {
                "Node": "dummy2",
                "Address": "10.0.1.2"
              }
            ]
          EOS
          @stubs.get('/v1/catalog/nodes') { [200, {}, json] }
          nodes = @client.nodes
          expect(nodes).to be_is_a Array
          expect(nodes.size).to eq(2)

          expect(nodes[0]).to be_is_a Hash
          expect(nodes[0].keys).to eq(%i(node address))
          expect(nodes[0][:node]).to eq('dummy1')
          expect(nodes[0][:address]).to eq('10.0.1.1')

          expect(nodes[1]).to be_is_a Hash
          expect(nodes[1].keys).to eq(%i(node address))
          expect(nodes[1][:node]).to eq('dummy2')
          expect(nodes[1][:address]).to eq('10.0.1.2')
        end

        it 'request nil when some error occurred while request' do
          @stubs.get('/v1/catalog/nodes') { [404, {}, ''] }
          expect(@client.nodes).to be_nil
        end
      end

      describe '#sequential_try' do
        it 'retry with next faraday when previous faraday is failed' do
          faraday1 = @faraday.clone
          faraday2 = @faraday.clone
          faraday3 = @faraday.clone
          @client.instance_variable_set(:@faradaies, [faraday1, faraday2, faraday3])

          block = double(:block)
          expect(block).to receive(:call).with(faraday1).and_raise
          expect(block).to receive(:call).with(faraday2).and_return('dummy_result')
          expect(block).to_not receive(:call).with(faraday3)

          result = @client.send(:sequential_try) { |faraday| block.call(faraday) }
          expect(result).to eq('dummy_result')
        end
      end
    end
  end
end
