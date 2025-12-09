class Trailer < ApplicationRecord
  self.primary_key = "id"

  has_many :drivers
  has_many :tours, foreign_key: :trailer_id  # NEU

  validates :license_plate, presence: true
  scope :sortiert, -> { order(:id) }
  scope :by_license_plate, -> { order(:license_plate) }

  def to_s
    license_plate || "Anhänger #{id}"
  end
end
