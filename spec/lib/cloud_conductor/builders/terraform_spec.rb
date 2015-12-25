module CloudConductor
  module Builders
    describe Terraform do
      include_context 'default_resources'

      let(:cloud_aws) { FactoryGirl.create(:cloud, :aws) }

      before do
        @builder = Terraform.new cloud_aws, environment
      end

      describe '#initialize' do
        it 'keep @cloud' do
          cloud = @builder.instance_variable_get :@cloud
          expect(cloud).to eq(cloud_aws)
        end

        it 'keep @environment' do
          env = @builder.instance_variable_get :@environment
          expect(env).to eq(environment)
        end
      end

      describe '#build_infrastructure' do
        before do
          allow(@builder).to receive(:generate_template)
          allow(@builder).to receive(:execute_terraform)
          allow(@builder).to receive(:frontend_addresses)
          allow(@builder).to receive(:reset)
        end

        it 'call subroutines except #reset' do
          expect(@builder).to receive(:generate_template).ordered
          expect(@builder).to receive(:execute_terraform).ordered
          expect(@builder).not_to receive(:reset)
          @builder.send(:build_infrastructure)
        end

        it 'call #reset when some error has been occurred while processing' do
          allow(@builder).to receive(:execute_terraform).and_raise
          expect(@builder).to receive(:reset)
          expect { @builder.send(:build_infrastructure) }.to raise_error(RuntimeError)
        end
      end

      describe '#generate_template' do
        before do
          @parent = double(:parent, save: nil, cleanup: nil)
          @mod = double(:module)

          allow(FileUtils).to receive(:mkdir_p)
          allow(CloudConductor::Terraform::Parent).to receive(:new).and_return(@parent)
          allow(CloudConductor::Terraform::Module).to receive(:new).and_return(@mod)
        end

        it 'will create directory if directory does not exist' do
          allow(Dir).to receive(:exist?).and_return(false)
          expect(FileUtils).to receive(:mkdir_p).with(/[0-9a-f\-]{36}/)
          @builder.send(:generate_template, cloud_aws, environment)
        end

        it 'call Parent#save and Parent#cleanup to generate/cleanup parent template' do
          expect(@parent).to receive(:save).ordered
          @builder.send(:generate_template, cloud_aws, environment)
        end

        it 'return directory path that contains parent template.tf' do
          path = @builder.send(:generate_template, cloud_aws, environment)
          expect(path).to match(%r(/tmp/terraform/[0-9a-f\-]{36}$))
        end
      end

      describe '#execute_terraform' do
        before do
          allow(@builder).to receive(:bootstrap_expect).and_return([])

          @terraform = double(:terraform, get: true, plan: {}, apply: true, output: {})
          allow(Rterraform::Client).to receive(:new).and_return(@terraform)
        end

        it 'call subroutines except #reset' do
          expect(@terraform).to receive(:get).ordered
          expect(@terraform).to receive(:plan).ordered
          expect(@terraform).to receive(:apply).ordered
          expect(@terraform).to receive(:output).ordered
          @builder.send(:execute_terraform, 'directory', {})
        end

        it 'return terraform output as hash' do
          result = @builder.send(:execute_terraform, 'directory', {})
          expect(result).to eq({})
        end
      end

      describe '#bootstrap_expect' do
        it 'return size of instances in output that is created by terraform plan for aws' do
          outputs = {
            'null_resource' => {},
            'module' => {
              'tomcat' => {
                'aws_instance' => {
                  'web_server' => {},
                  'ap_server' => {},
                  'db_server' => {}
                }
              },
              'zabbix' => {
                'aws_instance' => {
                  'web_server' => {}
                }
              }
            }
          }

          expect(@builder.send(:bootstrap_expect, outputs)).to eq(4)
        end

        it 'return size of instances in output that is created by terraform plan for openstack' do
          outputs = {
            'null_resource' => {},
            'module' => {
              'tomcat' => {
                'openstack_compute_instance_v2' => {
                  'web_server' => {},
                  'ap_server' => {},
                  'db_server' => {}
                }
              },
              'zabbix' => {
                'openstack_compute_instance_v2' => {
                  'web_server' => {}
                }
              }
            }
          }

          expect(@builder.send(:bootstrap_expect, outputs)).to eq(4)
        end
      end

      describe '#frontend_addresses' do
        it 'returns frontend addresses in output hash' do
          outputs = {
            'cloud_conductor_init.shared_security_group' => 'sg-xxxxxx',
            'tomcat.frontend_addresses' => '203.0.113.1',
            'dummy.frontend_addresses' => '',
            'zabbix.frontend_addresses' => '203.0.113.2'
          }

          expect(@builder.send(:frontend_addresses, outputs)).to eq('203.0.113.1, 203.0.113.2')
        end
      end

      describe '#cloud_variables' do
        it 'returns hash which has some keys to authorize aws if cloud is aws' do
          cloud = FactoryGirl.build(:cloud, :aws)
          result = @builder.send(:cloud_variables, cloud)
          expect(result).to be_is_a(Hash)
          expect(result).to eq(
            aws_access_key: cloud.key,
            aws_secret_key: cloud.secret,
            aws_region: cloud.entry_point
          )
        end

        it 'returns hash which has some keys to authorize openstack if cloud is openstack' do
          cloud = FactoryGirl.build(:cloud, :openstack)
          result = @builder.send(:cloud_variables, cloud)
          expect(result).to be_is_a(Hash)
          expect(result).to eq(
            openstack_user_name: cloud.key,
            openstack_password: cloud.secret,
            openstack_auth_url: cloud.entry_point + 'v2.0',
            openstack_tenant_name: cloud.tenant_name
          )
        end

        it 'returns empty hash if unknown cloud has been specified' do
          cloud = Cloud.new(type: :unknown)
          result = @builder.send(:cloud_variables, cloud)
          expect(result).to be_is_a(Hash)
          expect(result).to eq({})
        end
      end
    end
  end
end
