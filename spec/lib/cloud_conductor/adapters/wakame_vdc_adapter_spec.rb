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
          @image = double('image', state: 'available')
          allow(@image).to receive(:destroy)

          allow(Hijiki::DcmgrResource::V1203::Image).to receive_message_chain(:find).and_return(@image)
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
      end
    end
  end
end
