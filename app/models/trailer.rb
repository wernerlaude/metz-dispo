class Trailer < ApplicationRecord
  self.primary_key = 'id'

  has_many :drivers
  has_many :tours, foreign_key: :trailer_id  # NEU

  validates :license_plate, presence: true
  scope :sortiert, -> { order(:id) }

  def to_s
    name || "Anhänger #{id}"
  end
end
