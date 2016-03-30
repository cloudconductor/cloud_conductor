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
        destroy_backup_object(image.backup_object_id)
        true
      end

      def destroy_backup_object(backup_object_id)
        faraday = Faraday.new(@options[:entry_point])
        result = faraday.get("backup_objects/#{backup_object_id}")
        return false if result.status == 404
        return false if JSON.parse(result.body)['state'] == 'deleted'

        result = faraday.delete("backup_objects/#{backup_object_id}")
        fail unless result.success?
        true
      end
    end
  end
end
