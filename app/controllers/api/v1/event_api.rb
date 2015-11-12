module API
  module V1
    class EventAPI < API::V1::Base
      resource :environments do
        desc 'List events'
        params do
          requires :id, type: Integer, desc: 'Environment id'
        end
        get '/:id/events' do
          environment = ::Environment.find(declared_params[:id])
          authorize!(:read, environment)

          environment.event.list
        end

        desc 'Show event'
        params do
          requires :id, type: Integer, desc: 'Environment id'
          requires :event_id, type: String, desc: 'Event id'
        end
        get '/:id/events/:event_id' do
          environment = ::Environment.find(declared_params[:id])
          authorize!(:read, environment)

          event = environment.event.find(declared_params[:event_id])
          if event
            event.as_json(detail: true)
          else
            status 404
            { error: "Couldn't find Event with 'event-id'=#{declared_params[:event_id]}" }
          end
        end

        desc 'Fire event'
        params do
          requires :id, type: Integer, desc: 'Environment id'
          requires :event, type: String, desc: 'Event name'
        end
        post '/:id/events' do
          environment = ::Environment.find(declared_params[:id])
          authorize!(:update, environment)

          event_id = environment.event.fire(declared_params[:event])
          status 202
          { event_id: event_id }
        end
      end
    end
  end
end
