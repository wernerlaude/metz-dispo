# app/services/firebird_connect_api.rb
require "net/http"
require "json"

class FirebirdConnectApi
  BASE_URL = ENV.fetch("FIREBIRD_API_URL", "http://192.168.33.61/api/v1")

  def self.get(path)
    uri = URI("#{BASE_URL}#{path}")

    request = Net::HTTP::Get.new(uri)
    request["Content-Type"] = "application/json"

    http = Net::HTTP.new(uri.host, uri.port)
    http.read_timeout = 30

    response = http.request(request)

    OpenStruct.new(
      success?: response.code == "200",
      code: response.code,
      body: response.body
    )
  rescue => e
    Rails.logger.error "FirebirdConnectApi GET error: #{e.message}"
    OpenStruct.new(
      success?: false,
      code: "500",
      body: { error: e.message }.to_json
    )
  end

  def self.post(path, body)
    uri = URI("#{BASE_URL}#{path}")

    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"
    request.body = body.to_json

    http = Net::HTTP.new(uri.host, uri.port)
    http.read_timeout = 30

    response = http.request(request)

    OpenStruct.new(
      success?: response.code == "200",
      code: response.code,
      body: response.body
    )
  rescue => e
    Rails.logger.error "FirebirdConnectApi POST error: #{e.message}"
    OpenStruct.new(
      success?: false,
      code: "500",
      body: { error: e.message }.to_json
    )
  end

  def self.patch(path, body)
    uri = URI("#{BASE_URL}#{path}")

    request = Net::HTTP::Patch.new(uri)
    request["Content-Type"] = "application/json"
    request.body = body.to_json

    http = Net::HTTP.new(uri.host, uri.port)
    http.read_timeout = 30

    response = http.request(request)

    OpenStruct.new(
      success?: response.code == "200",
      code: response.code,
      body: response.body
    )
  rescue => e
    Rails.logger.error "FirebirdConnectApi PATCH error: #{e.message}"
    OpenStruct.new(
      success?: false,
      code: "500",
      body: { error: e.message }.to_json
    )
  end
end
