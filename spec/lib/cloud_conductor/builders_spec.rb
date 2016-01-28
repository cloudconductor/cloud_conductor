require 'cloud_conductor/builders'

module CloudConductor
  describe Builders do
    before do
      @cloud = FactoryGirl.build(:cloud, type: 'aws')
      @environment = FactoryGirl.build(:environment)

      allow(CloudConductor::Config).to receive_message_chain(:system_build, :providers) { @config_providers }
      allow(@environment).to receive_message_chain(:blueprint_history, :providers) { @providers }
    end

    describe '.builder' do
      it 'raise error if core doesn\'t support any provider' do
        @config_providers = []
        expect { Builders.builder(@cloud, @environment) }.to raise_error(RuntimeError)
      end

      it 'returns builder instance that has highest priority in configured providers' do
        @config_providers = [:terraform, :cloud_formation]
        @providers = {
          'aws' => %w(cloud_formation terraform)
        }
        builder = Builders.builder(@cloud, @environment)
        expect(builder).to be_is_a CloudConductor::Builders::Terraform
      end

      it 'returns builder instance that has second priority in providers if environment can\'t be built by highest provider' do
        @config_providers = [:terraform, :cloud_formation]
        @providers = {
          'aws' => %w(cloud_formation)
        }
        builder = Builders.builder(@cloud, @environment)
        expect(builder).to be_is_a CloudConductor::Builders::CloudFormation
      end
    end
  end
end
