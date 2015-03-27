module Consul
  class Client
    class Catalog
      def initialize(faraday)
        @faraday = faraday
      end

      def nodes(data_center = nil)
        @faraday.params[:dc] = data_center if data_center
        response = @faraday.get('catalog/nodes')
        return nil unless response.success?

        JSON.parse(response.body).map do |entry|
          { node: entry['Node'], address: entry['Address'] }
        end
      end
    end
  end
end
