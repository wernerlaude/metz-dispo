class Trailer < ApplicationRecord
  has_many :drivers
  has_many :tours, foreign_key: :trailer_id  # NEU

  validates :license_plate, presence: true

  def to_s
    name || "Anhänger #{id}"
  end
end
