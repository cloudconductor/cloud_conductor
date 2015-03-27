class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  before_action :set_default_headers

  unless Rails.env.development?
    # Rails returns the last matching rescue_from value
    rescue_from Exception, with: :internal_server_error
    rescue_from ActiveRecord::RecordNotFound, with: :not_found
    rescue_from ActionController::RoutingError, with: :not_found
    rescue_from ActionController::MethodNotAllowed, with: :not_found
    rescue_from CanCan::AccessDenied, with: :forbidden
  end

  protected

  def set_default_headers
    ActionDispatch::Response.default_headers.merge(
      'X-Frame-Options' => 'DENY',
      'X-Content-Type-Options' => 'nosniff',
      'X-XSS-Protection' => '1;'
    )
  end

  def access_denied(exception)
    # Log.debug
    redirect_to root_path, alert: exception.message
  end

  def internal_server_error(_exception)
    # Log.error
    render file: "#{Rails.root}/public/500.html", status: 500
  end

  def not_found(_exception)
    # Log.debug
    render file: "#{Rails.root}/public/404.html", status: 404
  end

  def forbidden(_exception)
    render file: "#{Rails.root}/public/403.html", status: 403
  end
end
