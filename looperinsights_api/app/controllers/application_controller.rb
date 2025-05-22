class ApplicationController < ActionController::API
  include Paginatable
  include ActionController::HttpAuthentication::Basic::ControllerMethods

  before_action :authenticate

  private

  def authenticate
    username = ENV.fetch("AUTH_USERNAME", "user")
    password = ENV.fetch("AUTH_PASSWORD", "password")

    authenticate_or_request_with_http_basic do |provided_user, provided_pass|
      ActiveSupport::SecurityUtils.secure_compare(provided_user, username) &
        ActiveSupport::SecurityUtils.secure_compare(provided_pass, password)
    end
  end
end
