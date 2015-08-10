module Metronome
  describe NodeTaskResult do
    before do
      @client = double('client')
    end

    describe '.list' do
      it 'return empty array when kvs hasn\'t result' do
        allow(@client).to receive_message_chain(:kv, :get).and_return(nil)

        results = NodeTaskResult.list(@client, '00000000-0000-0000-0000-000000000000', 0)
        expect(results).to eq([])
      end

      it 'return array of NodeTaskResult that are created from kvs response' do
        response = {
          'metronome/results/6195e436-d702-4866-56af-06889ac08364/0/node1' => {
            'EventID' => '6195e436-d702-4866-56af-06889ac08364',
            'No' => 0,
            'Node' => 'node1',
            'Status' => 'success',
            'StartedAt' => '2015-08-07T15:32:59+09:00',
            'FinishedAt' => '2015-08-07T15:33:05+09:00'
          },
          'metronome/results/6195e436-d702-4866-56af-06889ac08364/0/node1/log' => 'dummy log'
        }
        allow(@client).to receive_message_chain(:kv, :get).and_return(response)

        results = NodeTaskResult.list(@client, '00000000-0000-0000-0000-000000000000', 0)
        expect(results.size).to eq(1)
        expect(results).to be_is_a(Array)
        expect(results.first).to be_is_a(Metronome::NodeTaskResult)
      end
    end

    describe '.find' do
      it 'return nil when kvs hasn\'t result' do
        allow(@client).to receive_message_chain(:kv, :get).and_return(nil)

        results = NodeTaskResult.find(@client, '00000000-0000-0000-0000-000000000000', 0, 'node0')
        expect(results).to be_nil
      end

      it 'initialize NodeTaskResult with kvs response' do
        response = {
          'EventID' => '6195e436-d702-4866-56af-06889ac08364',
          'No' => 0,
          'Node' => 'node1',
          'Status' => 'success',
          'StartedAt' => '2015-08-07T15:32:59+09:00',
          'FinishedAt' => '2015-08-07T15:33:05+09:00'
        }
        response_log = 'dummy log'
        kv = double(:kv)
        allow(kv).to receive(:get).with(%r{^metronome/results/[0-9a-f-]+/\d+/[^/]+$}).and_return(response)
        allow(kv).to receive(:get).with(%r{/log$}).and_return(response_log)
        allow(@client).to receive(:kv).and_return(kv)

        expect(NodeTaskResult).to receive(:new).with(@client, response, response_log)
        NodeTaskResult.find(@client, '6195e436-d702-4866-56af-06889ac08364', 0, 'node1')
      end
    end

    describe '#initialize' do
      it 'return NodeTaskResult that is created from kvs response' do
        response = {
          'EventID' => '6195e436-d702-4866-56af-06889ac08364',
          'No' => 0,
          'Node' => 'node1',
          'Status' => 'success',
          'StartedAt' => '2015-08-07T15:32:59+09:00',
          'FinishedAt' => '2015-08-07T15:33:05+09:00'
        }

        result = NodeTaskResult.new(@client, response, 'dummy log')
        expect(result).to be_is_a(NodeTaskResult)
        expect(result.id).to eq('6195e436-d702-4866-56af-06889ac08364')
        expect(result.no).to eq(0)
        expect(result.node).to eq('node1')
        expect(result.status).to eq(:success)
        expect(result.started_at).to be_is_a(DateTime)
        expect(result.started_at).to eq(DateTime.new(2015, 8, 7, 15, 32, 59, '+0900'))
        expect(result.finished_at).to be_is_a(DateTime)
        expect(result.finished_at).to eq(DateTime.new(2015, 8, 7, 15, 33, 05, '+0900'))
        expect(result.log).to eq('dummy log')
      end

      it 'use nil instead of finished_at when initialize with unfinished result' do
        response = {
          'EventID' => '6195e436-d702-4866-56af-06889ac08364',
          'No' => 0,
          'Node' => 'node1',
          'Status' => 'success',
          'StartedAt' => '2015-08-07T15:32:59+09:00'
        }

        result = NodeTaskResult.new(@client, response, 'dummy log')
        expect(result.finished_at).to be_nil
      end
    end

    context 'with instance' do
      before do
        response = {
          'EventID' => '6195e436-d702-4866-56af-06889ac08364',
          'No' => 0,
          'Node' => 'node1',
          'Status' => 'success',
          'StartedAt' => '2015-08-07T15:32:59+09:00',
          'FinishedAt' => '2015-08-07T15:33:05+09:00'
        }
        @node_result = NodeTaskResult.new(@client, response, 'dummy log')
      end

      describe '#finished?' do
        it 'return true when status is success' do
          @node_result.status = :success
          expect(@node_result.finished?).to be_truthy
        end

        it 'return true when status is error' do
          @node_result.status = :error
          expect(@node_result.finished?).to be_truthy
        end

        it 'return false when status isn\'t success and error' do
          @node_result.status = :inprogress
          expect(@node_result.finished?).to be_falsey
        end
      end

      describe '#success?' do
        it 'return true when status is success' do
          @node_result.status = :success
          expect(@node_result.finished?).to be_truthy
        end

        it 'return true when status isn\'t success' do
          @node_result.status = :inprogress
          expect(@node_result.finished?).to be_falsey
        end
      end

      describe '#as_json' do
        it 'return Hash that is excluded client field' do
          expect(@node_result.as_json.keys).to eq(%w(id no node status started_at finished_at log))
        end
      end
    end
  end
end
