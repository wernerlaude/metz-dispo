class AddressRestriction < ApplicationRecord
  self.primary_key = "id"

  belongs_to :driver
  belongs_to :loading_location, foreign_key: :liefadrnr, primary_key: :kundennr

  validates :driver_id, presence: true
  validates :liefadrnr, presence: true

  def to_s
    "#{driver.full_name} - #{loading_location.werk_name}"
  end
end
