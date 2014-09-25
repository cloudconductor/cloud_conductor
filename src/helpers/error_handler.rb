module ErrorHandler
  def self.registered(app)
    app.error 404 do
      json message: 'Not Found'
    end
    app.error 500 do
      Log.error "#{env['sinatra.error'].class}: #{env['sinatra.error'].message}"
      json message: 'Unexpected error occured. Please contact server administrator.'
    end
  end
end
