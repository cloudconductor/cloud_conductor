module ErrorHandler
  def self.registered(app)
    app.error 404 do
      json message: 'Not Found' if response.body.empty?
    end
    app.error 500 do
      Log.error env['sinatra.error']
      json message: 'Unexpected error occurred. Please contact server administrator.'
    end
  end
end
