class AddressRestriction < ApplicationRecord
  belongs_to :driver
  belongs_to :address

  validates :driver_id, uniqueness: { scope: :address_id }
end
