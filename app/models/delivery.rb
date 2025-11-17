# app/models/delivery.rb
class Delivery < ApplicationRecord
  self.table_name = "wws_vliefer1"
  self.primary_key = "liefschnr"

  # Associations
  has_many :delivery_positions,
           foreign_key: "liefschnr",
           primary_key: "liefschnr"

  belongs_to :customer,
             foreign_key: "kundennr",
             primary_key: "kundennr",
             optional: true

  belongs_to :delivery_address,
             class_name: "Address",
             foreign_key: "liefadrnr",
             primary_key: "nummer",
             optional: true

  # NEU: SalesOrder Association
  belongs_to :sales_order,
             foreign_key: "vauftragnr",
             primary_key: "vauftragnr",
             optional: true

  # Validierungen
  validates :liefschnr, presence: true, uniqueness: true
  validates :kundennr, presence: true

  # Helper Methoden
  def delivery_number
    liefschnr
  end

  def customer_name
    kundname
  end

  def delivery_date
    datum
  end

  def formatted_address
    if delivery_address
      parts = [
        delivery_address.name1,
        delivery_address.strasse,
        "#{delivery_address.plz} #{delivery_address.ort}"
      ].compact.reject(&:blank?)

      parts.any? ? parts.join(", ") : "Keine Adresse"
    else
      "Lieferadresse #{liefadrnr}"
    end
  end
end