class Vehicle < ApplicationRecord
  has_many :drivers, dependent: :nullify

  validates :license_plate, presence: true, uniqueness: true
  validates :vehicle_number, presence: true, uniqueness: true

  # Enums für vehicle_type
  enum :vehicle_type, {
    stueckgut: 0,
    silo: 1,
    siloan: 2,
    sattelzug: 3,
    auflieger: 4,
    aufliegerki: 5,
    aufliegersilo: 6,
    kipperlkw: 7,
    kipperanh: 8,
    sprinter: 9,
    caddy: 10,
    kombi: 11
  }, prefix: true

  scope :by_license_plate, -> { order(:license_plate) }

  # Labels für Vehicle Types
  VEHICLE_TYPE_LABELS = {
    "stueckgut" => "Stückgut",
    "silo" => "Silo LKW",
    "siloan" => "Silo Anhänger",
    "sattelzug" => "Sattelzugmaschine",
    "auflieger" => "Auflieger Schubboden",
    "aufliegerki" => "Auflieger Kipper",
    "aufliegersilo" => "Auflieger Silo",
    "kipperlkw" => "Kipper LKW",
    "kipperanh" => "Kipperanhänger",
    "sprinter" => "Sprinter",
    "caddy" => "Caddy",
    "kombi" => "Kombi"
  }.freeze

  def vehicle_type_label
    VEHICLE_TYPE_LABELS[vehicle_type] || vehicle_type
  end

  # Für Select-Optionen in Forms
  def self.vehicle_type_options_for_select
    vehicle_types.keys.map { |type| [ VEHICLE_TYPE_LABELS[type], type ] }
  end

  # Für Inline Edit - JSON Format
  def self.vehicle_type_options_for_json
    vehicle_types.keys.map { |type| { value: type, text: VEHICLE_TYPE_LABELS[type] } }
  end

  def to_s
    license_plate
  end

  # Für Dropdowns im Modal (liefert Array von Hashes)
  def self.for_select
    pluck(:vehicle_number, :license_plate, :vehicle_short).map do |vn, lp, vs|
      { vehicle_number: vn, license_plate: lp, vehicle_short: vs }
    end
  end

  # Für Anzeige in Tabellen: lkwnr -> "AN-AB 123 (Actros)"
  def self.display_name_for(lkwnr)
    return nil if lkwnr.blank?

    vehicle = find_by(vehicle_number: lkwnr)
    return lkwnr unless vehicle

    if vehicle.vehicle_short.present?
      "#{vehicle.license_plate} (#{vehicle.vehicle_short})"
    else
      vehicle.license_plate
    end
  end

  def display_name
    parts = [ license_plate ]
    parts << "(#{vehicle_short})" if vehicle_short.present?
    parts.join(" ")
  end
end
