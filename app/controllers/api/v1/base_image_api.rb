module API
  module V1
    class BaseImageAPI < API::V1::Base
      resource :base_images do
        desc 'List base images'
        get '/' do
          authorize!(:read, BaseImage)
          ::BaseImage.all.select do |base_image|
            can?(:read, base_image)
          end
        end

        desc 'Show base_image'
        params do
          requires :id, type: Integer, desc: 'BaseImage id'
        end
        get '/:id' do
          base_image = ::BaseImage.find(params[:id])
          authorize!(:read, base_image)
          base_image
        end

        desc 'Create base_image'
        params do
          requires :cloud_id, type: Integer, desc: 'Cloud id'
          requires :os, type: String, desc: 'Operating system name'
          requires :ssh_username, type: String, desc: 'SSH login username to created instance'
          optional :source_image, type: String, desc: 'AMI id on AWS or image UUID on openstack'
        end
        post '/' do
          authorize!(:create, ::BaseImage)
          ::BaseImage.create!(declared_params)
        end

        desc 'Update base_image'
        params do
          requires :id, type: Integer, desc: 'BaseImage id'
          requires :cloud_id, type: Integer, desc: 'Cloud id'
          requires :os, type: String, desc: 'Operating system name'
          requires :ssh_username, type: String, desc: 'SSH login username to created instance'
          optional :source_image, type: String, desc: 'AMI id on AWS or image UUID on openstack'
        end
        put '/:id' do
          base_image = ::BaseImage.find(params[:id])
          authorize!(:update, base_image)
          base_image.update_attributes!(declared_params)
          base_image
        end

        desc 'Destroy base_image'
        params do
          requires :id, type: Integer, desc: 'BaseImage id'
        end
        delete '/:id' do
          base_image = ::BaseImage.find(params[:id])
          authorize!(:destroy, base_image)
          base_image.destroy
          status 204
        end
      end
    end
  end
end
