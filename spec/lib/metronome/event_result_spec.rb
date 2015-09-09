module Metronome
  describe EventResult do
    before do
      @client = double('client')
    end

    describe '.list' do
      it 'return empty array when kvs hasn\'t result' do
        allow(@client).to receive_message_chain(:kv, :get).and_return(nil)

        results = EventResult.list(@client)
        expect(results).to eq([])
      end

      it 'return array of EventResult that are created from kvs response' do
        response = {
          'metronome/results/6195e436-d702-4866-56af-06889ac08364' => {
            'ID' => '6195e436-d702-4866-56af-06889ac08364',
            'Name' => 'configure',
            'Status' => 'success',
            'StartedAt' => '2015-08-07T15:32:50+09:00',
            'FinishedAt' => '2015-08-07T15:49:15+09:00'
          }
        }
        allow(@client).to receive_message_chain(:kv, :get).and_return(response)

        results = EventResult.list(@client)
        expect(results.size).to eq(1)
        expect(results).to be_is_a(Array)
        expect(results.first).to be_is_a(Metronome::EventResult)
      end
    end

    describe '.find' do
      it 'return nil when kvs hasn\'t result' do
        allow(@client).to receive_message_chain(:kv, :get).and_return(nil)

        results = EventResult.find(@client, '00000000-0000-0000-0000-000000000000')
        expect(results).to be_nil
      end

      it 'initialize EventResult with kvs response' do
        response = {
          'ID' => '6195e436-d702-4866-56af-06889ac08364',
          'Name' => 'configure',
          'Status' => 'success',
          'StartedAt' => '2015-08-07T15:32:50+09:00',
          'FinishedAt' => '2015-08-07T15:49:15+09:00'
        }
        allow(@client).to receive_message_chain(:kv, :get).and_return(response)

        expect(EventResult).to receive(:new).with(@client, response)
        EventResult.find(@client, '6195e436-d702-4866-56af-06889ac08364')
      end
    end

    describe '#initialize' do
      it 'return EventResult that is created from kvs response' do
        response = {
          'ID' => '6195e436-d702-4866-56af-06889ac08364',
          'Name' => 'configure',
          'Status' => 'success',
          'StartedAt' => '2015-08-07T15:32:50+09:00',
          'FinishedAt' => '2015-08-07T15:49:15+09:00'
        }

        result = EventResult.new(@client, response)
        expect(result).to be_is_a(EventResult)
        expect(result.id).to eq('6195e436-d702-4866-56af-06889ac08364')
        expect(result.name).to eq('configure')
        expect(result.status).to eq(:success)
        expect(result.started_at).to be_is_a(DateTime)
        expect(result.started_at).to eq(DateTime.new(2015, 8, 7, 15, 32, 50, '+0900'))
        expect(result.finished_at).to be_is_a(DateTime)
        expect(result.finished_at).to eq(DateTime.new(2015, 8, 7, 15, 49, 15, '+0900'))
      end

      it 'use nil instead of finished_at when initialize with unfinished result' do
        response = {
          'ID' => '6195e436-d702-4866-56af-06889ac08364',
          'Name' => 'configure',
          'Status' => 'success',
          'StartedAt' => '2015-08-07T15:32:50+09:00'
        }

        result = EventResult.new(@client, response)
        expect(result.finished_at).to be_nil
      end
    end

    context 'with instance' do
      before do
        response = {
          'ID' => '6195e436-d702-4866-56af-06889ac08364',
          'Name' => 'configure',
          'Status' => 'success',
          'StartedAt' => '2015-08-07T15:32:50+09:00',
          'FinishedAt' => '2015-08-07T15:49:15+09:00'
        }
        @event_result = EventResult.new(@client, response)
      end

      describe '#finished?' do
        it 'return true when status is success' do
          @event_result.status = :success
          expect(@event_result.finished?).to be_truthy
        end

        it 'return true when status is error' do
          @event_result.status = :error
          expect(@event_result.finished?).to be_truthy
        end

        it 'return false when status isn\'t success and error' do
          @event_result.status = :inprogress
          expect(@event_result.finished?).to be_falsey
        end
      end

      describe '#success?' do
        it 'return true when status is success' do
          @event_result.status = :success
          expect(@event_result.finished?).to be_truthy
        end

        it 'return true when status isn\'t success' do
          @event_result.status = :inprogress
          expect(@event_result.finished?).to be_falsey
        end
      end

      describe '#as_json' do
        it 'return Hash that is excluded client field' do
          expect(@event_result.as_json.keys).to eq(%w(id name status started_at finished_at))
        end
      end

      describe '#task_results' do
        it 'will call TaskResult.list and return it when first request' do
          expect(TaskResult).to receive(:list).with(@client, '6195e436-d702-4866-56af-06889ac08364').and_return([])
          expect(@event_result.task_results).to eq([])
        end

        it 'return cache instead of calling TaskResult.list when already cached' do
          expect(TaskResult).not_to receive(:list)
          @event_result.instance_variable_set(:@task_results, [])
          expect(@event_result.task_results).to eq([])
        end
      end

      describe '#refresh!' do
        it 'will retrieve TaskResult and refresh recursively' do
          task_result = double(:task_result)
          expect(TaskResult).to receive(:list).with(@client, '6195e436-d702-4866-56af-06889ac08364').and_return([task_result])
          expect(task_result).to receive(:refresh!)
          expect(@event_result.refresh!).to eq(@event_result)
        end
      end
    end
  end
end
