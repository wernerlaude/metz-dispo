class Vehicle < ApplicationRecord
  has_many :drivers, dependent: :nullify

  validates :license_plate, presence: true, uniqueness: true

  # Enums für vehicle_type
  enum :vehicle_type, {
    lkw: 0,
    werkstatt: 1,
    subunternehmer: 2,
    sprinter: 3
  }, prefix: true

  scope :by_license_plate, -> { order(:license_plate) }

  # Labels für Vehicle Types
  VEHICLE_TYPE_LABELS = {
    "lkw" => "LKW",
    "werkstatt" => "Werkstatt",
    "subunternehmer" => "?",
    "sprinter" => "?"
  }.freeze

  def vehicle_type_label
    VEHICLE_TYPE_LABELS[vehicle_type] || vehicle_type
  end

  # Für Select-Optionen in Forms
  def self.vehicle_type_options_for_select
    vehicle_types.keys.map { |type| [ VEHICLE_TYPE_LABELS[type], type ] }
  end

  def to_s
    license_plate
  end

  def display_name
    parts = [ license_plate ]
    parts << "(#{vehicle_number})" if vehicle_number.present?
    parts.join(" ")
  end
end
