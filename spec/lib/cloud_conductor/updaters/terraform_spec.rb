require 'cloud_conductor/updaters/terraform'

module CloudConductor
  module Updaters
    describe Terraform do
      include_context 'default_resources'

      let(:cloud_aws) { FactoryGirl.create(:cloud, :aws) }
      let(:cloud_openstack) { FactoryGirl.create(:cloud, :openstack) }

      before do
        @updater = Terraform.new cloud_aws, environment
      end

      describe '#initialize' do
        it 'keep @cloud' do
          expect(@updater.instance_variable_get(:@cloud)).to eq(cloud_aws)
        end

        it 'keep @environment' do
          expect(@updater.instance_variable_get(:@environment)).to eq(environment)
        end
      end

      describe '#update_infrastructure' do
        before do
          allow(@updater).to receive(:generate_template)
          allow(@updater).to receive(:save_ssh_private_key).and_yield('tmp/terraform/dummy.pem')
          allow(@updater).to receive(:terraform_variables).and_return({})
          allow(@updater).to receive(:execute_terraform)
          allow(@updater).to receive(:frontend_address)
          allow(@updater).to receive(:consul_addresses)
          allow(@updater).to receive(:reset)
        end

        it 'call subroutines except #reset' do
          expect(@updater).to receive(:generate_template).ordered
          expect(@updater).to receive(:save_ssh_private_key).ordered
          expect(@updater).to receive(:terraform_variables).ordered
          expect(@updater).to receive(:execute_terraform).ordered
          expect(@updater).to receive(:frontend_address).ordered
          expect(@updater).to receive(:consul_addresses).ordered
          expect(@updater).not_to receive(:reset)
          @updater.send(:update_infrastructure)
        end

        it 'call #reset when some error has been occurred while processing' do
          allow(@updater).to receive(:execute_terraform).and_raise
          expect(@updater).to receive(:reset)
          expect { @updater.send(:update_infrastructure) }.to raise_error(RuntimeError)
        end

        it 'update cloud of stack to target cloud when success' do
          environment.stacks << FactoryGirl.build(:stack)
          @updater.send(:update_infrastructure)
          expect(environment.stacks.map(&:cloud)).to all(eq(cloud_aws))
        end

        it 'update status of stack to :CREATE_COMPLETE when success' do
          environment.stacks << FactoryGirl.build(:stack)
          @updater.send(:update_infrastructure)
          expect(environment.stacks).to all(be_create_complete)
        end

        it 'update status of stack to :ERROR when some error has been occurred' do
          environment.stacks << FactoryGirl.build(:stack)
          allow(@updater).to receive(:execute_terraform).and_raise
          expect { @updater.send(:update_infrastructure) }.to raise_error(RuntimeError)
          expect(environment.stacks).to all(be_error)
        end
      end

      describe '#reset' do
      end

      describe '#generate_template' do
        before do
          @parent = double(:parent, save: nil, cleanup: nil, modules: [])
          @mod = double(:module)

          allow(@updater).to receive(:template_directory).and_return('template_directory')
          allow(FileUtils).to receive(:mkdir_p)
          allow(CloudConductor::Terraform::Parent).to receive(:new).and_return(@parent)
          allow(CloudConductor::Terraform::Module).to receive(:new).and_return(@mod)
          allow(@updater).to receive(:merge_default_mapping)
        end

        it 'will create directory if directory does not exist' do
          allow(Dir).to receive(:exist?).and_return(false)
          expect(FileUtils).to receive(:mkdir_p).with('template_directory')
          @updater.send(:generate_template, cloud_aws, environment)
        end

        it 'call Parent#save and Parent#cleanup to generate/cleanup parent template' do
          expect(@parent).to receive(:save).ordered
          @updater.send(:generate_template, cloud_aws, environment)
        end

        it 'call #merge_default_mapping when target cloud is openstack' do
          expect(@updater).to receive(:merge_default_mapping)
          environment.blueprint_history.pattern_snapshots = FactoryGirl.build_list(:pattern_snapshot, 2)
          @updater.send(:generate_template, cloud_openstack, environment)
        end
      end

      describe '#execute_terraform' do
        before do
          allow(@updater).to receive(:bootstrap_expect).and_return([])
          allow(@updater).to receive(:destroy_rules)

          planned_resources = { add: {}, destroy: {}, change: {} }
          @terraform = double(:terraform, get: true, show: {}, plan: planned_resources, apply: true, output: {})
          allow(RubyTerraform::Client).to receive(:new).and_return(@terraform)
        end

        it 'call subroutines except #reset' do
          expect(@terraform).to receive(:get).ordered
          expect(@terraform).to receive(:show).ordered
          expect(@terraform).to receive(:plan).ordered
          expect(@terraform).to receive(:apply).ordered
          expect(@terraform).to receive(:output).ordered
          @updater.send(:execute_terraform, {})
        end

        it 'return terraform output as hash' do
          result = @updater.send(:execute_terraform, {})
          expect(result).to eq({})
        end
      end

      describe '#destroy_rules' do
        it 'destroy all aws_security_group_rule resources' do
          resources = {
            'module' => {
              'amanda_pattern' => {
                'aws_security_group' => {
                  'backup_restore_security_group' => {}
                },
                'aws_security_group_rule' => {
                  'rule1' => {},
                  'rule2' => {}
                }
              },
              'common_network' => {
                'aws_internet_gateway' => {
                  'main' => {}
                }
              },
              'fluentd_pattern' => {
                'aws_security_group_rule' => {
                  'rule3' => {},
                  'rule4' => {}
                }
              }
            }
          }

          expected_rules = []
          expected_rules << 'module.amanda_pattern.aws_security_group_rule.rule1'
          expected_rules << 'module.amanda_pattern.aws_security_group_rule.rule2'
          expected_rules << 'module.fluentd_pattern.aws_security_group_rule.rule3'
          expected_rules << 'module.fluentd_pattern.aws_security_group_rule.rule4'

          terraform = double(:terraform)
          expect(terraform).to receive(:destroy).with(anything, target: expected_rules)
          @updater.send(:destroy_rules, terraform, {}, resources)
        end
      end

      describe '#bootstrap_expect' do
        it 'return 0 when target hash is empty' do
          expect(@updater.send(:bootstrap_expect, {})).to eq(0)
        end

        it 'return size of instances in output that is created by terraform plan for aws' do
          resources = {
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

          expect(@updater.send(:bootstrap_expect, resources)).to eq(4)
        end

        it 'return size of instances in output that is created by terraform plan for openstack' do
          resources = {
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

          expect(@updater.send(:bootstrap_expect, resources)).to eq(4)
        end

        it 'return size of instances in output that is created by terraform plan for aws with count argument' do
          resources = {
            'null_resource' => {},
            'module' => {
              'tomcat' => {
                'aws_instance' => {
                  'web_server' => {},
                  'ap_server' => {
                    '0' => {},
                    '1' => {}
                  },
                  'db_server' => {
                    '0' => {},
                    '1' => {},
                    '2' => {}
                  }
                }
              },
              'zabbix' => {
                'aws_instance' => {
                  'web_server' => {}
                }
              }
            }
          }

          expect(@updater.send(:bootstrap_expect, resources)).to eq(7)
        end
      end

      describe '#frontend_address' do
        it 'raise error if environment has multiple frontend addresses' do
          outputs = {
            'cloud_conductor_init.shared_security_group' => 'sg-xxxxxx',
            'tomcat.frontend_address' => '203.0.113.1',
            'dummy.frontend_address' => '',
            'zabbix.frontend_address' => '203.0.113.2'
          }

          expect { @updater.send(:frontend_address, outputs) }.to raise_error(RuntimeError)
        end

        it 'returns frontend address in output hash' do
          outputs = {
            'cloud_conductor_init.shared_security_group' => 'sg-xxxxxx',
            'tomcat.frontend_address' => '203.0.113.1'
          }

          expect(@updater.send(:frontend_address, outputs)).to eq('203.0.113.1')
        end
      end

      describe '#consul_addresses' do
        it 'returns consul addresses in output hash' do
          outputs = {
            'cloud_conductor_init.shared_security_group' => 'sg-xxxxxx',
            'tomcat.consul_addresses' => '203.0.113.1, 203.0.113.2',
            'dummy.consul_addresses' => '',
            'zabbix.consul_addresses' => '203.0.113.3'
          }

          expect(@updater.send(:consul_addresses, outputs)).to eq('203.0.113.1, 203.0.113.2, 203.0.113.3')
        end
      end

      describe '#save_ssh_private_key' do
        before do
          allow(File).to receive(:open).with(%r{/tmp/terraform/[0-9a-f-]*.pem}, anything, anything)
          allow(File).to receive(:exist?).with(%r{/tmp/terraform/[0-9a-f-]*.pem}).and_return(true)
          allow(FileUtils).to receive(:rm).with(%r{/tmp/terraform/[0-9a-f-]*.pem})
        end

        it 'yield block with path of private key' do
          expect { |b| @updater.send(:save_ssh_private_key, 'dummy_key', &b) }.to yield_with_args(kind_of(String))
        end

        it 'remove generated file of private key' do
          expect(FileUtils).to receive(:rm).with(%r{/tmp/terraform/[0-9a-f-]*.pem})
          @updater.send(:save_ssh_private_key, 'dummy_key') {}
        end

        it 'remove generated file of private key when some errors occurred' do
          expect(FileUtils).to receive(:rm).with(%r{/tmp/terraform/[0-9a-f-]*.pem})
          expect { @updater.send(:save_ssh_private_key, 'dummy_key') { fail } }.to raise_error(RuntimeError)
        end
      end

      describe '#template_directory' do
        it 'return template directory which contains environment name and cloud name' do
          environment.created_at = DateTime.new(2016, 3, 23, 9, 46, 10, '+0900')
          expect(@updater.send(:template_directory)).to match(/environment#{environment.id}_20160323094610_#{cloud_aws.name}/)
        end
      end

      describe '#terraform_variables' do
        it 'combine #cloud_variables and #image_variables' do
          expect(@updater).to receive(:cloud_variables).and_return(cloud: 'dummy1')
          expect(@updater).to receive(:image_variables).and_return(image: 'dummy2')

          expect(@updater.send(:terraform_variables)).to include(cloud: 'dummy1', image: 'dummy2')
        end
      end

      describe '#cloud_variables' do
        it 'returns hash which has some keys to authorize aws if cloud is aws' do
          cloud = FactoryGirl.build(:cloud, :aws)
          result = @updater.send(:cloud_variables, cloud, environment)
          expect(result).to be_is_a(Hash)
          expect(result).to eq(
            aws_access_key: cloud.key,
            aws_secret_key: cloud.secret,
            aws_region: cloud.entry_point
          )
        end

        it 'returns hash which has some keys to authorize openstack if cloud is openstack' do
          cloud = FactoryGirl.build(:cloud, :openstack)
          result = @updater.send(:cloud_variables, cloud, environment)
          expect(result).to be_is_a(Hash)
          expect(result).to eq(
            os_user_name: cloud.key,
            os_password: cloud.secret,
            os_auth_url: cloud.entry_point + 'v2.0',
            os_tenant_name: cloud.tenant_name,
            environment_id: environment.id
          )
        end

        it 'returns empty hash if unknown cloud has been specified' do
          cloud = Cloud.new(type: :unknown)
          result = @updater.send(:cloud_variables, cloud, environment)
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

          result = @updater.send(:image_variables, cloud, environment)
          expect(result).to be_is_a(Hash)
          expect(result).to include(
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

          result = @updater.send(:image_variables, cloud, environment)
          expect(result).to be_is_a(Hash)
          expect(result).to include(
            web_image: 'ami-000000',
            db_image: 'ami-222222'
          )
        end

        it 'combine roles with underscore if image has multiple roles' do
          pattern_snapshots = FactoryGirl.build_list(:pattern_snapshot, 1)
          pattern_snapshots[0].images << FactoryGirl.build(:image, role: 'web, ap', cloud: cloud, image: 'ami-000000')
          environment.blueprint_history.pattern_snapshots = pattern_snapshots

          result = @updater.send(:image_variables, cloud, environment)
          expect(result).to be_is_a(Hash)
          expect(result).to include(
            web_ap_image: 'ami-000000'
          )
        end

        it 'returns hash which has ssh username to connect' do
          base_image = FactoryGirl.build(:base_image, ssh_username: 'centos')
          image = FactoryGirl.build(:image, role: 'ap', cloud: cloud, image: 'ami-000000', base_image: base_image)
          pattern_snapshots = FactoryGirl.build_list(:pattern_snapshot, 1)
          pattern_snapshots[0].images << image
          environment.blueprint_history.pattern_snapshots = pattern_snapshots

          result = @updater.send(:image_variables, cloud, environment)
          expect(result).to be_is_a(Hash)
          expect(result).to include(
            ssh_username: 'centos'
          )
        end
      end

      describe '#merge_default_mapping' do
        before do
          network = double(:network, id: '11111111-1111-1111-1111-111111111111')
          allow(@updater).to receive(:default_gateway).and_return(network)
        end

        it 'return nil without exception when mapping is nil' do
          @updater.send(:merge_default_mapping, cloud_openstack, nil)
        end

        it 'return without change when gateway_id is already specified' do
          mapping = { gateway_id: { type: 'static', value: '00000000-0000-0000-0000-000000000000' } }
          result = @updater.send(:merge_default_mapping, cloud_openstack, mapping)
          expect(result[:gateway_id][:value]).to eq('00000000-0000-0000-0000-000000000000')
        end

        it 'update gateway_id by default external network via neutron' do
          mapping = { gateway_id: { type: 'static', value: 'auto' } }
          result = @updater.send(:merge_default_mapping, cloud_openstack, mapping)
          expect(result[:gateway_id][:value]).to eq('11111111-1111-1111-1111-111111111111')
        end
      end

      describe '#default_gateway' do
        it 'return network' do
          @neutron = double(:neutron, networks: [])
          allow(Fog::Network).to receive(:new).and_return(@neutron)

          network = double(:network, id: '11111111-1111-1111-1111-111111111111', router_external: true)
          allow(@neutron).to receive(:networks).and_return([network])

          expect(@updater.send(:default_gateway, cloud_openstack)).to eq(network)
        end
      end
    end
  end
end
