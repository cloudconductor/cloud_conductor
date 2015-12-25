module Consul
  class Client
    class Catalog
      def initialize(faradaies)
        @faradaies = faradaies
      end

      def nodes(data_center = nil)
        sequential_try do |faraday|
          faraday.params[:dc] = data_center if data_center
          response = faraday.get('catalog/nodes')
          break nil unless response.success?

          JSON.parse(response.body).map do |entry|
            { node: entry['Node'], address: entry['Address'] }
          end
        end
      end

      def sequential_try
        fail "Block doesn't given" unless block_given?

        @faradaies.find do |faraday|
          begin
            break yield faraday
          rescue
            nil
          end
        end
      end
    end
  end
end
