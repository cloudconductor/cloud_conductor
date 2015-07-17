describe API do
  include ApiSpecHelper
  include_context 'default_api_settings'

  describe 'EventAPI' do
    before { environment }

    describe 'GET /environments/:id/events' do
      let(:method) { 'get' }
      let(:url) { "/api/v1/environments/#{environment.id}/events" }
      let(:result) do
        [{ id: 1 }]
      end

      before do
        dummy_event_log = double(:event_log, as_json: { id: 1 })
        allow_any_instance_of(Environment).to receive_message_chain(:event, :list).and_return([dummy_event_log])
      end

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

    describe 'GET /environments/:id/events/:event_id' do
      let(:method) { 'get' }
      let(:url) { "/api/v1/environments/#{environment.id}/events/2" }
      let(:result) do
        { id: 1 }
      end

      before do
        dummy_event_log = double(:event_log, as_json: { id: 1 })
        allow_any_instance_of(Environment).to receive_message_chain(:event, :find).and_return(dummy_event_log)
      end

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

    describe 'POST /environments/:id/events' do
      let(:method) { 'post' }
      let(:url) { "/api/v1/environments/#{environment.id}/events" }
      let(:params) do
        { event: 'dummy' }
      end
      let(:result) do
        { event_id: 1 }
      end

      before do
        allow_any_instance_of(Environment).to receive_message_chain(:event, :fire).and_return(1)
      end

      context 'not_logged_in' do
        it_behaves_like('401 Unauthorized')
      end

      context 'normal_account', normal: true do
        it_behaves_like('403 Forbidden')
      end

      context 'administrator', admin: true do
        it_behaves_like('202 Accepted')
      end

      context 'project_owner', project_owner: true do
        it_behaves_like('202 Accepted')
      end

      context 'project_operator', project_operator: true do
        it_behaves_like('202 Accepted')
      end
    end
  end
end
