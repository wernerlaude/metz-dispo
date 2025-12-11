# app/models/geocode_cache.rb
class GeocodeCache < ApplicationRecord
  validates :address_hash, presence: true, uniqueness: true
  validates :address_string, presence: true

  scope :found, -> { where(found: true) }
  scope :not_found, -> { where(found: false) }

  def coordinates
    return nil unless found? && lat.present? && lng.present?
    { lat: lat.to_f, lng: lng.to_f }
  end
end
