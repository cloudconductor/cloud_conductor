require 'hijiki'

module CloudConductor
  module Adapters
    class WakameVdcAdapter < AbstractAdapter
      TYPE = :wakame_vdc

      def initialize(options = {})
        @post_processes = []
        @options = options.with_indifferent_access

        ::ActiveResource::Base.site = @options[:entry_point]
        ::ActiveResource::Connection.set_vdc_account_uuid(@options[:key])
      end

      def destroy_image(image_id)
        image = Hijiki::DcmgrResource::V1203::Image.find(image_id)

        image.destroy if image && image.state != 'deleted'
      end
    end
  end
end
