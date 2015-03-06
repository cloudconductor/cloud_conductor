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

    describe 'GET /base_images/:id' do
      let(:method) { 'get' }
      let(:url) { "/api/v1/base_images/#{base_image.id}" }
      let(:result) { format_iso8601(base_image) }

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

    describe 'POST /base_images' do
      let(:method) { 'post' }
      let(:url) { '/api/v1/base_images' }
      let(:params) { FactoryGirl.attributes_for(:base_image, cloud_id: cloud.id) }
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
    end

    #     describe 'PUT /base_images/:id' do
    #       let(:method) { 'put' }
    #       let(:url) { "/api/v1/base_images/#{base_image.id}" }
    #       let(:params) do
    #         {
    #           'os' => 'centos7',
    #           'ssh_username' => 'root',
    #           'source_image' => SecureRandom.uuid
    #         }
    #       end
    #       let(:result) do
    #         base_image.as_json.merge(params).merge(
    #           'created_at' => base_image.created_at.iso8601(3),
    #           'updated_at' => String
    #         )
    #       end
    #
    #       context 'not_logged_in' do
    #         it_behaves_like('401 Unauthorized')
    #       end
    #
    #       context 'normal_account', normal: true do
    #         it_behaves_like('403 Forbidden')
    #       end
    #
    #       context 'administrator', admin: true do
    #         it_behaves_like('200 OK')
    #       end
    #
    #       context 'project_owner', project_owner: true do
    #         it_behaves_like('200 OK')
    #       end
    #
    #       context 'project_operator', project_operator: true do
    #         it_behaves_like('200 OK')
    #       end
    #     end

    describe 'DELETE /base_images/:id' do
      let(:method) { 'delete' }
      let(:url) { "/api/v1/base_images/#{new_base_image.id}" }
      let(:new_base_image) { FactoryGirl.create(:base_image, cloud_id: cloud.id) }

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
