describe API do
  include ApiSpecHelper
  include_context 'default_api_settings'

  describe 'BaseImageAPI' do
    before { base_image }

    describe 'GET /base_images' do
      let(:method) { 'get' }
      let(:url) { '/api/v1/base_images' }
      let(:result) { format_iso8601([base_image]) }

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
        it_behaves_like('200 OK')
      end

      context 'project_operator', project_operator: true do
        it_behaves_like('200 OK')
      end

      context 'with cloud' do
        let(:params) { { cloud_id: base_image.cloud.id } }
        let(:result) { format_iso8601([base_image]) }

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
          it_behaves_like('200 OK')
        end

        context 'project_operator', project_operator: true do
          it_behaves_like('200 OK')
        end

        context 'in not exists cloud_id' do
          let(:params) { { cloud_id: 9999 } }
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

      context 'with project' do
        let(:params) { { project_id: base_image.project.id } }
        let(:result) { format_iso8601([base_image]) }

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
          it_behaves_like('200 OK')
        end

        context 'project_operator', project_operator: true do
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

    describe 'GET /base_images/:id' do
      let(:method) { 'get' }
      let(:url) { "/api/v1/base_images/#{base_image.id}" }
      let(:result) { format_iso8601(base_image) }

      context 'not_logged_in' do
        it_behaves_like('401 Unauthorized')
      end

      context 'not_exist_id', admin: true do
        let(:url) { '/api/v1/base_images/0' }
        it_behaves_like('404 Not Found')
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

    describe 'POST /base_images' do
      let(:method) { 'post' }
      let(:url) { '/api/v1/base_images' }
      let(:params) { FactoryGirl.attributes_for(:base_image, cloud_id: cloud.id, platform_version: '6.5') }
      let(:result) do
        params.merge(
          'id' => Fixnum,
          'created_at' => String,
          'updated_at' => String
        )
      end

      context 'not_logged_in' do
        it_behaves_like('401 Unauthorized')
      end

      context 'normal_account', normal: true do
        it_behaves_like('403 Forbidden')
      end

      context 'administrator', admin: true do
        it_behaves_like('201 Created')
      end

      context 'project_owner', project_owner: true do
        it_behaves_like('201 Created')
      end

      context 'project_operator', project_operator: true do
        it_behaves_like('201 Created')
      end

      context 'in not existing coloud_id' do
        let(:params) { FactoryGirl.attributes_for(:base_image, cloud_id: 9999) }

        context 'not_logged_in' do
          it_behaves_like('401 Unauthorized')
        end

        context 'normal_account', normal: true do
          it_behaves_like('400 BadRequest')
        end

        context 'administrator', admin: true do
          it_behaves_like('400 BadRequest')
        end

        context 'project_owner', project_owner: true do
          it_behaves_like('400 BadRequest')
        end

        context 'project_operator', project_operator: true do
          it_behaves_like('400 BadRequest')
        end
      end
    end

    describe 'PUT /base_images/:id' do
      let(:method) { 'put' }
      let(:url) { "/api/v1/base_images/#{base_image.id}" }
      let(:params) do
        {
          'platform' => 'CentOS',
          'ssh_username' => 'root',
          'source_image' => SecureRandom.uuid
        }
      end
      let(:result) do
        base_image.as_json.merge(params).merge(
          'created_at' => base_image.created_at.iso8601(3),
          'updated_at' => String
        )
      end

      context 'not_logged_in' do
        it_behaves_like('401 Unauthorized')
      end

      context 'not_exist_id', admin: true do
        let(:url) { '/api/v1/base_images/0' }
        it_behaves_like('404 Not Found')
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

    describe 'DELETE /base_images/:id' do
      let(:method) { 'delete' }
      let(:url) { "/api/v1/base_images/#{base_image.id}" }

      context 'not_logged_in' do
        it_behaves_like('401 Unauthorized')
      end

      context 'not_exist_id', admin: true do
        let(:url) { '/api/v1/base_images/0' }
        it_behaves_like('404 Not Found')
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
