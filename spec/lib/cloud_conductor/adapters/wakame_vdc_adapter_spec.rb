module CloudConductor
  module Adapters
    describe WakameVdcAdapter do
      before do
        options = {
          key: 'a-shpoolxx',
          entry_point: 'http://localhost:9001/api/12.03/'
        }
        @adapter = WakameVdcAdapter.new options
      end

      it 'extend AbstractAdapter class' do
        expect(WakameVdcAdapter.superclass).to eq(AbstractAdapter)
      end

      it 'has :wakame_vdc type' do
        expect(WakameVdcAdapter::TYPE).to eq(:wakame_vdc)
      end

      describe '#destroy_image' do
        before do
          @image = double('image', state: 'available', backup_object_id: 'bo-xxxxxx')
          allow(@image).to receive(:destroy)

          allow(Hijiki::DcmgrResource::V1203::Image).to receive_message_chain(:find).and_return(@image)
          allow(@adapter).to receive(:destroy_backup_object)
        end

        it 'execute without exception' do
          @adapter.destroy_image 'wmi-xxxxxx'
        end

        it 'call V1208::Image#destroy to delete created image on wakame' do
          expect(@image).to receive(:destroy)

          @adapter.destroy_image 'wmi-xxxxxx'
        end

        it 'suppress API request with already deleted image' do
          allow(@image).to receive(:state).and_return('deleted')
          expect(@image).not_to receive(:destroy)

          @adapter.destroy_image 'wmi-xxxxxx'
        end

        it 'call #destroy_backup_object with backup_object_id' do
          expect(@adapter).to receive(:destroy_backup_object).with('bo-xxxxxx')
          @adapter.destroy_image 'wmi-xxxxxx'
        end
      end

      describe '#destroy_backup_object' do
        before do
          @stubs = Faraday::Adapter::Test::Stubs.new

          original_method = Faraday.method(:new)
          allow(Faraday).to receive(:new) do |*args, &block|
            original_method.call(*args) do |builder|
              builder.adapter :test, @stubs
              yield block if block
            end
          end
        end

        it 'request API to delete backup object and return true if success to delete' do
          @stubs.get('/api/12.03/backup_objects/bo-xxxxxx') { [200, {}, '{}'] }
          @stubs.delete('/api/12.03/backup_objects/bo-xxxxxx') do
            [200, {}, '{}']
          end
          expect(@adapter.destroy_backup_object('bo-xxxxxx')).to be_truthy
        end

        it 'return false without delete request when target object already deleted' do
          @stubs.get('/api/12.03/backup_objects/bo-xxxxxx') { [200, {}, '{ "state": "deleted" }'] }
          @stubs.delete('/api/12.03/backup_objects/bo-xxxxxx') do
            fail
          end
          expect(@adapter.destroy_backup_object('bo-xxxxxx')).to be_falsey
        end

        it 'return false without delete request when target object does not exist' do
          @stubs.get('/api/12.03/backup_objects/bo-xxxxxx') { [404, {}, ''] }
          @stubs.delete('/api/12.03/backup_objects/bo-xxxxxx') do
            fail
          end
          expect(@adapter.destroy_backup_object('bo-xxxxxx')).to be_falsey
        end

        it 'raise error when some error occurred while deleting backup object' do
          @stubs.get('/api/12.03/backup_objects/bo-xxxxxx') { [200, {}, '{}'] }
          @stubs.delete('/api/12.03/backup_objects/bo-xxxxxx') do
            [400, {}, '{}']
          end
          expect { @adapter.destroy_backup_object('bo-xxxxxx') }.to raise_error RuntimeError
        end
      end
    end
  end
end
