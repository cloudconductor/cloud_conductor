module API
  module V1
    class BaseImageAPI < API::V1::Base
      resource :base_images do
        desc 'List base images'
        params do
          optional :cloud_id, type: Integer, desc: 'Cloud id'
          optional :project_id, type: Integer, desc: 'Project id'
        end
        get '/' do
          if params[:cloud_id]
            base_images = ::BaseImage.where(cloud_id: params[:cloud_id])
          elsif params[:project_id]
            base_images = ::BaseImage.select_by_project_id(params[:project_id])
          else
            base_images = ::BaseImage.all
          end
          base_images.select do |base_image|
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
          requires :cloud_id, type: Integer, exists_id: :cloud, desc: 'Cloud id'
          requires :ssh_username, type: String, desc: 'SSH login username to created instance'
          requires :source_image, type: String, desc: 'AMI id on AWS or image UUID on openstack'
          optional :os_version, type: String, desc: 'Operating system name', default: 'default'
        end
        post '/' do
          cloud = ::Cloud.find_by(id: params[:cloud_id])
          authorize!(:read, cloud)
          authorize!(:create, ::BaseImage, project: cloud.project)
          ::BaseImage.create!(declared_params)
        end

        desc 'Update base_image'
        params do
          requires :id, type: Integer, desc: 'BaseImage id'
          optional :ssh_username, type: String, desc: 'SSH login username to created instance'
          optional :source_image, type: String, desc: 'AMI id on AWS or image UUID on openstack'
          optional :os_version, type: String, desc: 'Operating system name', default: 'default'
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
