# app/models/customer.rb
class Customer < ApplicationRecord
  self.table_name = "wws_kunden1"
  self.primary_key = "kundennr"

  # Assoziationen
  has_many :sales_orders,
           foreign_key: "kundennr",
           dependent: :restrict_with_error

  has_many :deliveries,
           foreign_key: "kundennr",
           dependent: :restrict_with_error

  has_many :addresses,
           foreign_key: "knr",
           dependent: :restrict_with_error

  # Attribute für Import
  attr_accessor :skip_validations

  # Validierungen - lockerer für automatisch importierte Kunden
  validates :kundennr, presence: true, uniqueness: true
  validates :kundgruppe, presence: true, unless: :skip_validations
  validates :bundesland, presence: true, length: { is: 2 }, unless: :skip_validations, allow_blank: true

  # Scopes
  scope :active, -> { where.not(gekuendigt: true) }
  scope :cooperative_members, -> { where.not(mitgliednr: nil) }

  # Helper Methoden
  def full_name
    name1 = addresses.where(art: "KUNDE").first&.name1
    name1 || kundennr.to_s
  end

  def cooperative_member?
    mitgliednr.present?
  end
end
