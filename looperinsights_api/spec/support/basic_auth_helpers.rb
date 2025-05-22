# spec/support/basic_auth_helpers.rb
module BasicAuthHelpers
  def basic_auth_header(user = "user", pass = "password")
    {
      "Authorization" => ActionController::HttpAuthentication::Basic.encode_credentials(user, pass)
    }
  end

  def default_username
    ENV.fetch("AUTH_USERNAME", "user")
  end

  def default_password
    ENV.fetch("AUTH_PASSWORD", "password")
  end
end
