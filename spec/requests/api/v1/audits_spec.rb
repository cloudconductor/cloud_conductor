describe API do
  include ApiSpecHelper
  include_context 'default_api_settings'

  describe 'AuditAPI' do
    before { audit }

    describe 'GET /audits' do
      let(:method) { 'get' }
      let(:url) { '/api/v1/audits' }
      let(:result) { format_iso8601([audit]) }

      context 'not_logged_in' do
        it_behaves_like('401 Unauthorized')
      end

      context 'normal_account', normal: true do
        let(:result) { [] }
        it_behaves_like('200 OK')
      end

      context 'administrator', admin: true do
        it_behaves_like('200 OK')
      end

      context 'project_owner', project_owner: true do
        let(:result) { [] }
        it_behaves_like('200 OK')
      end

      context 'project_operator', project_operator: true do
        let(:result) { [] }
        it_behaves_like('200 OK')
      end

      context 'with project' do
        let(:params) { { project_id: system.project.id } }

        context 'not_logged_in' do
          it_behaves_like('401 Unauthorized')
        end

        context 'normal_account', normal: true do
          let(:result) { [] }
          it_behaves_like('200 OK')
        end

        context 'administrator', admin: true do
          it_behaves_like('200 OK')
        end

        context 'project_owner', project_owner: true do
          let(:result) { [] }
          it_behaves_like('200 OK')
        end

        context 'project_operator', project_operator: true do
          let(:result) { [] }
          it_behaves_like('200 OK')
        end

        context 'in not exists project_id' do
          let(:params) { { project_id: 9999 } }
          let(:result) { [] }

          context 'not_logged_in' do
            it_behaves_like('401 Unauthorized')
          end

          context 'normal_account', normal: true do
            it_behaves_like('200 OK')
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
      end
    end
  end
end
