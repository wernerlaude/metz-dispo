class ApplicationController < ActionController::Base
  allow_browser versions: :modern
  # before_action :authenticate_me!

  def authenticate_me!
    authenticate_or_request_with_http_basic do |username, password|
      username == "Jochen!" && password == "Metz;"
    end
  end
end
