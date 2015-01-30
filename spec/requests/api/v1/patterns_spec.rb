describe API do
  include ApiSpecHelper
  include_context 'api'
  include_context 'default_accounts'

  describe 'PatternAPI' do
    let(:pattern) { FactoryGirl.create(:pattern) }
    before { pattern }

    describe 'GET /patterns' do
      let(:method) { 'get' }
      let(:url) { '/api/v1/patterns' }
      let(:result) { [api_attributes(pattern)] }

      context 'not_logged_in' do
        it_behaves_like('401 Unauthorized')
      end

      context 'normal_account', normal: true do
        it_behaves_like('403 Forbidden')
      end

      context 'administrator', admin: true do
        it_behaves_like('200 OK')
      end

      context 'project_owner', project_owner: true do
        it_behaves_like('200 OK')
      end

      context 'project_operator', project_operator: true do
        it_behaves_like('200 OK')
      end
    end

    describe 'GET /patterns/:id' do
      let(:method) { 'get' }
      let(:url) { "/api/v1/patterns/#{pattern.id}" }
      let(:result) { api_attributes(pattern) }

      context 'not_logged_in' do
        it_behaves_like('401 Unauthorized')
      end

      context 'normal_account', normal: true do
        it_behaves_like('403 Forbidden')
      end

      context 'administrator', admin: true do
        it_behaves_like('200 OK')
      end

      context 'project_owner', project_owner: true do
        it_behaves_like('200 OK')
      end

      context 'project_operator', project_operator: true do
        it_behaves_like('200 OK')
      end
    end

    describe 'POST /patterns' do
      let(:method) { 'post' }
      let(:url) { '/api/v1/patterns' }
      let(:params) { FactoryGirl.attributes_for(:pattern) }
      let(:result) do
        pattern.attributes.except('parameters').merge(
          'id' => Fixnum,
          'created_at' => String,
          'updated_at' => String,
          'revision' => String,
          'status' => :PENDING
        )
      end

      before do
        allow_any_instance_of(Pattern).to receive(:system).and_return(true)
        allow_any_instance_of(Pattern).to receive(:systemu).and_return(true)
        allow(Dir).to receive(:chdir).and_yield
        allow(YAML).to receive(:load_file).and_return(
          name: 'sample_platform_pattern',
          description: 'sample_platform_pattern',
          type: 'platform'
        )
        allow(File).to receive_message_chain(:open, :read).and_return('{ "Parameters": {}, "Resources": {} }')
      end

      context 'not_logged_in' do
        it_behaves_like('401 Unauthorized')
      end

      context 'normal_account', normal: true do
        it_behaves_like('403 Forbidden')
      end

      context 'administrator', admin: true do
        it_behaves_like('201 Accepted')
      end

      context 'project_owner', project_owner: true do
        it_behaves_like('201 Accepted')
      end

      context 'project_operator', project_operator: true do
        it_behaves_like('201 Accepted')
      end
    end

    describe 'PUT /patterns/:id' do
      let(:method) { 'put' }
      let(:url) { "/api/v1/patterns/#{pattern.id}" }
      let(:params) { FactoryGirl.attributes_for(:pattern) }
      let(:result) do
        pattern.attributes.except('parameters').merge(
          'created_at' => String,
          'updated_at' => String,
          'revision' => String,
          'status' => :PENDING
        )
      end

      before do
        allow_any_instance_of(Pattern).to receive(:system).and_return(true)
        allow_any_instance_of(Pattern).to receive(:systemu).and_return(true)
        allow(Dir).to receive(:chdir).and_yield
        allow(YAML).to receive(:load_file).and_return(
          name: 'sample_platform_pattern',
          description: 'sample_platform_pattern',
          type: 'platform'
        )
        allow(File).to receive_message_chain(:open, :read).and_return('{ "Parameters": {}, "Resources": {} }')
      end

      context 'not_logged_in' do
        it_behaves_like('401 Unauthorized')
      end

      context 'normal_account', normal: true do
        it_behaves_like('403 Forbidden')
      end

      context 'administrator', admin: true do
        it_behaves_like('201 Accepted')
      end

      context 'project_owner', project_owner: true do
        it_behaves_like('201 Accepted')
      end

      context 'project_operator', project_operator: true do
        it_behaves_like('201 Accepted')
      end
    end

    describe 'DELETE /patterns/:id' do
      let(:method) { 'delete' }
      let(:url) { "/api/v1/patterns/#{pattern.id}" }

      context 'not_logged_in' do
        it_behaves_like('401 Unauthorized')
      end

      context 'normal_account', normal: true do
        it_behaves_like('403 Forbidden')
      end

      context 'administrator', admin: true do
        it_behaves_like('204 No Content')
      end

      context 'project_owner', project_owner: true do
        it_behaves_like('204 No Content')
      end

      context 'project_operator', project_operator: true do
        it_behaves_like('204 No Content')
      end
    end
  end
end
