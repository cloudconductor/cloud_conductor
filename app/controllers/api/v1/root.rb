module API
  module V1
    class Root < API::V1::Base
      mount API::V1::TokenAPI
      mount API::V1::AccountAPI
      mount API::V1::ProjectAPI
      mount API::V1::CloudAPI
      mount API::V1::BaseImageAPI
      mount API::V1::BlueprintAPI
      mount API::V1::CatalogAPI
      mount API::V1::PatternAPI
      mount API::V1::SystemAPI
      mount API::V1::EnvironmentAPI
      mount API::V1::EventAPI
      mount API::V1::ApplicationAPI
      mount API::V1::ApplicationHistoryAPI
    end
  end
end
