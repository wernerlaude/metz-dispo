class Vehicle < ApplicationRecord
  has_many :drivers
  has_many :tours, foreign_key: :vehicle_id  # NEU

  validates :name, presence: true
  scope :active, -> { where(vehicle_type: !0) }

  def to_s
    name || "Fahrzeug #{id}"
  end
end
