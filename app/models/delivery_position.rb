# app/models/delivery_position.rb
class DeliveryPosition < ApplicationRecord
  self.table_name = "wws_vliefer2"
  self.primary_key = [ :liefschnr, :posnr ]

  # Assoziationen
  belongs_to :delivery,
             foreign_key: "liefschnr",
             primary_key: "liefschnr"

  belongs_to :tour, optional: true # DIREKTE Beziehung zur Tour

  # Validierungen
  validates :liefschnr, presence: true
  validates :posnr, presence: true, numericality: { greater_than: 0 }
  validates :artikelnr, presence: true
  validates :bezeichn1, presence: true
  validates :liefmenge, presence: true, numericality: { greater_than: 0 }
  validates :einheit, presence: true

  # Scopes
  scope :unassigned, -> { where(tour_id: nil) }
  scope :assigned, -> { where.not(tour_id: nil) }
  scope :by_tour, ->(tour) { where(tour: tour) }

  # Helper Methoden
  def product_name
    [ bezeichn1, bezeichn2 ].compact.join(" - ")
  end

  def quantity_with_unit
    "#{liefmenge} #{einheit}"
  end

  def weight_formatted
    "#{calculated_weight} kg"
  end

  def position_id
    "#{liefschnr}-#{posnr}"
  end


  def calculated_weight
    case einheit.upcase
    when "T", "TO"
      liefmenge * 1000
    when "KG"
      liefmenge
    when "SACK"
      liefmenge * 25
    when "BB"
      liefmenge * 600
    when "M³", "CBM"
      case artikelart
      when "FUTTER"
        liefmenge * 600
      when "DUENGER"
        liefmenge * 1200
      else
        liefmenge * 800
      end
    else
      0
    end
  end

  # Kunde über Delivery
  def customer
    delivery.customer
  end

  def customer_name
    delivery.customer_name
  end

  def delivery_address
    delivery.formatted_address # zurück zu englisch
  end

  def to_param
    "#{liefschnr}-#{posnr}"
  end
end
