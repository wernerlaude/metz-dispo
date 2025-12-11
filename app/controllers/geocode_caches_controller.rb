# app/controllers/geocode_caches_controller.rb
class GeocodeCachesController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [ :create ]

  # POST /geocode_caches
  # Frontend schickt Koordinaten nach erfolgreichem Geocoding
  def create
    address_string = params[:address_string].to_s.strip
    lat = params[:lat]
    lng = params[:lng]

    return render json: { error: "address_string required" }, status: :bad_request if address_string.blank?

    address_hash = Digest::MD5.hexdigest(address_string.downcase.strip)

    # Bereits vorhanden?
    existing = GeocodeCache.find_by(address_hash: address_hash)
    if existing
      return render json: { success: true, cached: true, id: existing.id }
    end

    # Neu speichern
    cache = GeocodeCache.create!(
      address_hash: address_hash,
      address_string: address_string,
      lat: lat.present? ? lat.to_f : nil,
      lng: lng.present? ? lng.to_f : nil,
      found: lat.present? && lng.present?,
      source: "frontend"
    )

    render json: { success: true, cached: false, id: cache.id }
  rescue => e
    Rails.logger.error "GeocodeCache create error: #{e.message}"
    render json: { success: false, error: e.message }, status: :unprocessable_entity
  end

  # GET /geocode_caches/lookup
  # Koordinaten für eine Adresse abrufen
  def lookup
    address_string = params[:address_string].to_s.strip
    return render json: { found: false } if address_string.blank?

    address_hash = Digest::MD5.hexdigest(address_string.downcase.strip)
    cached = GeocodeCache.find_by(address_hash: address_hash)

    if cached&.found?
      render json: { found: true, lat: cached.lat.to_f, lng: cached.lng.to_f }
    else
      render json: { found: false }
    end
  end
end
