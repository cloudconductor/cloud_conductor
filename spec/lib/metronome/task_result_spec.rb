module Metronome
  describe TaskResult do
    before do
      @client = double('client')
    end

    describe '.list' do
      it 'return empty array when kvs hasn\'t result' do
        allow(@client).to receive_message_chain(:kv, :get).and_return(nil)

        results = TaskResult.list(@client, '00000000-0000-0000-0000-000000000000')
        expect(results.size).to eq(0)
      end

      it 'return array of TaskResult that are created from kvs response' do
        response = {
          'metronome/results/6195e436-d702-4866-56af-06889ac08364/0' => {
            'EventID' => '6195e436-d702-4866-56af-06889ac08364',
            'No' => 0,
            'Name' => 'configure',
            'Status' => 'success',
            'StartedAt' => '2015-08-07T15:32:50+09:00',
            'FinishedAt' => '2015-08-07T15:49:15+09:00'
          }
        }
        allow(@client).to receive_message_chain(:kv, :get).and_return(response)

        results = TaskResult.list(@client, '6195e436-d702-4866-56af-06889ac08364')
        expect(results.size).to eq(1)
        expect(results).to be_is_a(Array)
        expect(results.first).to be_is_a(Metronome::TaskResult)
      end
    end

    describe '.find' do
      it 'return nil when kvs hasn\'t result' do
        allow(@client).to receive_message_chain(:kv, :get).and_return(nil)

        results = TaskResult.find(@client, '00000000-0000-0000-0000-000000000000', 0)
        expect(results).to be_nil
      end

      it 'initialize TaskResult with kvs response' do
        response = {
          'EventID' => '6195e436-d702-4866-56af-06889ac08364',
          'No' => 0,
          'Name' => 'configure',
          'Status' => 'success',
          'StartedAt' => '2015-08-07T15:32:50+09:00',
          'FinishedAt' => '2015-08-07T15:49:15+09:00'
        }
        allow(@client).to receive_message_chain(:kv, :get).and_return(response)

        expect(TaskResult).to receive(:new).with(@client, response)
        TaskResult.find(@client, '6195e436-d702-4866-56af-06889ac08364', 0)
      end
    end

    describe '#initialize' do
      it 'return TaskResult that is created from kvs response' do
        response = {
          'EventID' => '6195e436-d702-4866-56af-06889ac08364',
          'No' => 0,
          'Name' => 'configure',
          'Status' => 'success',
          'StartedAt' => '2015-08-07T15:32:50+09:00',
          'FinishedAt' => '2015-08-07T15:49:15+09:00'
        }

        result = TaskResult.new(@client, response)
        expect(result).to be_is_a(TaskResult)
        expect(result.id).to eq('6195e436-d702-4866-56af-06889ac08364')
        expect(result.no).to eq(0)
        expect(result.name).to eq('configure')
        expect(result.status).to eq(:success)
        expect(result.started_at).to be_is_a(DateTime)
        expect(result.started_at).to eq(DateTime.new(2015, 8, 7, 15, 32, 50, '+0900'))
        expect(result.finished_at).to be_is_a(DateTime)
        expect(result.finished_at).to eq(DateTime.new(2015, 8, 7, 15, 49, 15, '+0900'))
      end

      it 'use nil instead of finished_at when initialize with unfinished result' do
        response = {
          'EventID' => '6195e436-d702-4866-56af-06889ac08364',
          'No' => 0,
          'Name' => 'configure',
          'Status' => 'success',
          'StartedAt' => '2015-08-07T15:32:50+09:00'
        }

        result = TaskResult.new(@client, response)
        expect(result.finished_at).to be_nil
      end
    end

    context 'with instance' do
      before do
        response = {
          'EventID' => '6195e436-d702-4866-56af-06889ac08364',
          'No' => 0,
          'Name' => 'configure',
          'Status' => 'success',
          'StartedAt' => '2015-08-07T15:32:50+09:00',
          'FinishedAt' => '2015-08-07T15:49:15+09:00'
        }
        @task_result = TaskResult.new(@client, response)
      end

      describe '#finished?' do
        it 'return true when status is success' do
          @task_result.status = :success
          expect(@task_result.finished?).to be_truthy
        end

        it 'return true when status is error' do
          @task_result.status = :error
          expect(@task_result.finished?).to be_truthy
        end

        it 'return false when status isn\'t success and error' do
          @task_result.status = :inprogress
          expect(@task_result.finished?).to be_falsey
        end
      end

      describe '#success?' do
        it 'return true when status is success' do
          @task_result.status = :success
          expect(@task_result.finished?).to be_truthy
        end

        it 'return true when status isn\'t success' do
          @task_result.status = :inprogress
          expect(@task_result.finished?).to be_falsey
        end
      end

      describe '#as_json' do
        it 'return Hash that is excluded client field' do
          expect(@task_result.as_json.keys).to eq(%w(id no name status started_at finished_at))
        end
      end

      describe '#nodes' do
        it 'will call NodeTaskResult.list and return it when first request' do
          expect(NodeTaskResult).to receive(:list).with(@client, '6195e436-d702-4866-56af-06889ac08364', 0).and_return([])
          expect(@task_result.nodes).to eq([])
        end

        it 'return cache instead of calling TaskResult.list when already cached' do
          expect(NodeTaskResult).not_to receive(:list)
          @task_result.instance_variable_set(:@nodes, [])
          expect(@task_result.nodes).to eq([])
        end
      end

      describe '#refresh!' do
        it 'will retrieve NodeTaskResult' do
          node = double(:node)
          expect(NodeTaskResult).to receive(:list).with(@client, '6195e436-d702-4866-56af-06889ac08364', 0).and_return([node])
          expect(@task_result.refresh!).to eq(@task_result)
        end
      end
    end
  end
end
