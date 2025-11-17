# app/models/sales_order.rb
class SalesOrder < ApplicationRecord
  self.table_name = "wws_verkauf1"
  self.primary_key = "vauftragnr"

  # Assoziationen - KORRIGIERT
  belongs_to :customer,
             foreign_key: "kundennr",
             primary_key: "kundennr"

  belongs_to :delivery_address,
             foreign_key: "liefadrnr",
             primary_key: "nummer",
             class_name: "Address",
             optional: true

  has_many :sales_order_positions,
           foreign_key: "vauftragnr",
           dependent: :destroy

  has_many :deliveries,
           foreign_key: "vauftragnr",
           dependent: :restrict_with_error

  # Validierungen
  validates :vauftragnr, presence: true, uniqueness: true
  validates :datum, presence: true
  validates :kundennr, presence: true

  # Scopes
  scope :open, -> { where(erledigt: false) }
  scope :completed, -> { where(erledigt: true) }
  scope :today, -> { where(datum: Date.current) }

  # Helper Methoden
  def total_net
    sales_order_positions.sum(:netto) || 0.0
  end

  def open?
    !erledigt
  end

  def fully_delivered?
    sales_order_positions.all?(&:fully_delivered?)
  end
end
