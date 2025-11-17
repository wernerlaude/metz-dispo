class ApplicationController < ActionController::Base
  allow_browser versions: :modern
  # before_action :authenticate_me!

  # def authenticate_me!
  # authenticate_or_request_with_http_basic("Admin Area") do |username, password|
  # username == Rails.application.credentials[:username] && password == Rails.application.credentials[:password]
  # username == "Jochen!" && password == "Metz;"
  # end
  # end
end
