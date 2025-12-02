# app/services/firebird_connect_api.rb
require "net/http"
require "json"
require "openssl"

class FirebirdConnectApi
  BASE_URL = ENV.fetch("FIREBIRD_API_URL", "https://192.168.33.61/api/v1")

  def self.get(path)
    uri = URI("#{BASE_URL}#{path}")

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == "https")
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE  # Falls self-signed Zertifikat
    http.read_timeout = 30

    request = Net::HTTP::Get.new(uri)
    request["Content-Type"] = "application/json"

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

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == "https")
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    http.read_timeout = 30

    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"
    request.body = body.to_json

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

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == "https")
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    http.read_timeout = 30

    request = Net::HTTP::Patch.new(uri)
    request["Content-Type"] = "application/json"
    request.body = body.to_json

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
