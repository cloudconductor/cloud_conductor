module CloudConductor
  module Updaters
    def self.updater(cloud, environment)
      provider = CloudConductor::Config.system_build.providers.find do |provider|
        (environment.blueprint_history.providers[cloud.type] || []).include?(provider.to_s)
      end

      fail "All providers can\'t create this environment on #{cloud.type}" unless provider

      klass = CloudConductor::Updaters.const_get(provider.to_s.classify)
      fail "Target provider has not been implemented(#{provider})" unless klass && klass.class_of?(Updater)

      klass.new(cloud, environment)
    end
  end
end
