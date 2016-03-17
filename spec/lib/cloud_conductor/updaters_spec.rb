require 'cloud_conductor/updaters'

module CloudConductor
  describe Updaters do
    before do
      @cloud = FactoryGirl.build(:cloud, type: 'aws')
      @environment = FactoryGirl.build(:environment)

      allow(CloudConductor::Config).to receive_message_chain(:system_build, :providers) { @config_providers }
      allow(@environment).to receive_message_chain(:blueprint_history, :providers) { @providers }
    end

    describe '.updater' do
      it 'raise error if core doesn\'t support any provider' do
        @config_providers = []
        expect { Updaters.updater(@cloud, @environment) }.to raise_error(RuntimeError)
      end

      it 'raise error if providers is empty' do
        @config_providers = [:terraform, :cloud_formation]
        @providers = {}
        expect { Updaters.updater(@cloud, @environment) }.to raise_error("All providers can\'t create this environment on #{@cloud.type}")
      end

      it 'returns builder instance that has highest priority in configured providers' do
        @config_providers = [:terraform, :cloud_formation]
        @providers = {
          'aws' => %w(cloud_formation terraform)
        }
        updater = Updaters.updater(@cloud, @environment)
        expect(updater).to be_is_a CloudConductor::Updaters::Terraform
      end

      it 'returns builder instance that has second priority in providers if environment can\'t be built by highest provider' do
        @config_providers = [:terraform, :cloud_formation]
        @providers = {
          'aws' => %w(cloud_formation)
        }
        updater = Updaters.updater(@cloud, @environment)
        expect(updater).to be_is_a CloudConductor::Updaters::CloudFormation
      end
    end
  end
end
