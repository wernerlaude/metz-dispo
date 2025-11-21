class AddressRestriction < ApplicationRecord
  self.table_name = "address_restrictions"

  belongs_to :driver

  # Validierung: Ein Fahrer kann eine Lieferadresse nur einmal sperren
  validates :liefadrnr, uniqueness: { scope: :driver_id, message: "ist für diesen Fahrer bereits gesperrt" }
  validates :driver_id, presence: true
  validates :liefadrnr, presence: true
end
