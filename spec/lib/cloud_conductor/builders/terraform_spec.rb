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
          allow(@builder).to receive(:terraform_variables).and_return({})
          allow(@builder).to receive(:execute_terraform)
          allow(@builder).to receive(:frontend_addresses)
          allow(@builder).to receive(:reset)
        end

        it 'call subroutines except #reset' do
          expect(@builder).to receive(:generate_template).ordered
          expect(@builder).to receive(:terraform_variables).ordered
          expect(@builder).to receive(:execute_terraform).ordered
          expect(@builder).to receive(:frontend_addresses).ordered
          expect(@builder).not_to receive(:reset)
          @builder.send(:build_infrastructure)
        end

        it 'call #reset when some error has been occurred while processing' do
          allow(@builder).to receive(:execute_terraform).and_raise
          expect(@builder).to receive(:reset)
          expect { @builder.send(:build_infrastructure) }.to raise_error(RuntimeError)
        end

        it 'update cloud of stack to target cloud when success' do
          environment.stacks << FactoryGirl.build(:stack)
          @builder.send(:build_infrastructure)
          expect(environment.stacks.map(&:cloud)).to all(eq(cloud_aws))
        end

        it 'update status of stack to :CREATE_COMPLETE when success' do
          environment.stacks << FactoryGirl.build(:stack)
          @builder.send(:build_infrastructure)
          expect(environment.stacks).to all(be_create_complete)
        end

        it 'update status of stack to :ERROR when some error has been occurred' do
          environment.stacks << FactoryGirl.build(:stack)
          allow(@builder).to receive(:execute_terraform).and_raise
          expect { @builder.send(:build_infrastructure) }.to raise_error(RuntimeError)
          expect(environment.stacks).to all(be_error)
        end
      end

      describe '#destroy_infrastructure' do
        before do
          @terraform = double(:terraform, destroy: true)
          allow(Rterraform::Client).to receive(:new).and_return(@terraform)
        end

        it 'call subroutines except #reset' do
          expect(@terraform).to receive(:destroy)
          @builder.send(:destroy_infrastructure)
        end
      end

      describe '#reset' do
        it 'delegate delete logic to #destroy_infrastructure' do
          expect(@builder).to receive(:destroy_infrastructure)
          @builder.send(:reset)
        end
      end

      describe '#generate_template' do
        before do
          @parent = double(:parent, save: nil, cleanup: nil)
          @mod = double(:module)

          allow(@builder).to receive(:template_directory).and_return('template_directory')
          allow(FileUtils).to receive(:mkdir_p)
          allow(CloudConductor::Terraform::Parent).to receive(:new).and_return(@parent)
          allow(CloudConductor::Terraform::Module).to receive(:new).and_return(@mod)
        end

        it 'will create directory if directory does not exist' do
          allow(Dir).to receive(:exist?).and_return(false)
          expect(FileUtils).to receive(:mkdir_p).with('template_directory')
          @builder.send(:generate_template, cloud_aws, environment)
        end

        it 'call Parent#save and Parent#cleanup to generate/cleanup parent template' do
          expect(@parent).to receive(:save).ordered
          @builder.send(:generate_template, cloud_aws, environment)
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
          @builder.send(:execute_terraform, {})
        end

        it 'return terraform output as hash' do
          result = @builder.send(:execute_terraform, {})
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

      describe '#template_directory' do
        it 'return template directory which contains environment name and cloud name' do
          expect(@builder.send(:template_directory)).to match(/#{environment.name}_#{cloud_aws.name}/)
        end
      end

      describe '#terraform_variables' do
        it 'combine #cloud_variables and #image_variables' do
          expect(@builder).to receive(:cloud_variables).and_return(cloud: 'dummy1')
          expect(@builder).to receive(:image_variables).and_return(image: 'dummy2')

          expect(@builder.send(:terraform_variables)).to include(cloud: 'dummy1', image: 'dummy2')
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
            os_user_name: cloud.key,
            os_password: cloud.secret,
            os_auth_url: cloud.entry_point + 'v2.0',
            os_tenant_name: cloud.tenant_name
          )
        end

        it 'returns empty hash if unknown cloud has been specified' do
          cloud = Cloud.new(type: :unknown)
          result = @builder.send(:cloud_variables, cloud)
          expect(result).to be_is_a(Hash)
          expect(result).to eq({})
        end
      end

      describe '#image_variables' do
        it 'returns hash which has image id' do
          pattern_snapshots = FactoryGirl.build_list(:pattern_snapshot, 2)
          pattern_snapshots[0].images << FactoryGirl.build(:image, role: 'web', cloud: cloud, image: 'ami-000000')
          pattern_snapshots[0].images << FactoryGirl.build(:image, role: 'ap', cloud: cloud, image: 'ami-111111')
          pattern_snapshots[1].images << FactoryGirl.build(:image, role: 'db', cloud: cloud, image: 'ami-222222')
          environment.blueprint_history.pattern_snapshots = pattern_snapshots

          result = @builder.send(:image_variables, cloud, environment)
          expect(result).to be_is_a(Hash)
          expect(result).to eq(
            web_image: 'ami-000000',
            ap_image: 'ami-111111',
            db_image: 'ami-222222'
          )
        end

        it 'filter images by target cloud' do
          dummy_cloud = FactoryGirl.build(:cloud)
          pattern_snapshots = FactoryGirl.build_list(:pattern_snapshot, 1)
          pattern_snapshots[0].images << FactoryGirl.build(:image, role: 'web', cloud: cloud, image: 'ami-000000')
          pattern_snapshots[0].images << FactoryGirl.build(:image, role: 'ap', cloud: dummy_cloud, image: 'ami-111111')
          pattern_snapshots[0].images << FactoryGirl.build(:image, role: 'db', cloud: cloud, image: 'ami-222222')
          environment.blueprint_history.pattern_snapshots = pattern_snapshots

          result = @builder.send(:image_variables, cloud, environment)
          expect(result).to be_is_a(Hash)
          expect(result).to eq(
            web_image: 'ami-000000',
            db_image: 'ami-222222'
          )
        end

        it 'combine roles with underscore if image has multiple roles' do
          pattern_snapshots = FactoryGirl.build_list(:pattern_snapshot, 1)
          pattern_snapshots[0].images << FactoryGirl.build(:image, role: 'web, ap', cloud: cloud, image: 'ami-000000')
          environment.blueprint_history.pattern_snapshots = pattern_snapshots

          result = @builder.send(:image_variables, cloud, environment)
          expect(result).to be_is_a(Hash)
          expect(result).to eq(
            web_ap_image: 'ami-000000'
          )
        end
      end
    end
  end
end
