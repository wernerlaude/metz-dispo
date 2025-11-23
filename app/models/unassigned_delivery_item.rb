# app/models/unassigned_delivery_item.rb
class UnassignedDeliveryItem < ApplicationRecord
  # Validierungen
  validates :liefschnr, presence: true
  validates :posnr, presence: true
  validates :status, presence: true, inclusion: { in: %w[draft ready planned assigned completed cancelled] }

  # Scopes
  scope :draft, -> { where(status: "draft") }
  scope :ready, -> { where(status: "ready") }
  scope :planned, -> { where(status: "planned") }
  scope :not_invoiced, -> { where(invoiced: false) }
  scope :from_firebird, -> { where(tabelle_herkunft: "firebird_import") }
  scope :by_planned_date, -> { order(planned_date: :asc) }
  scope :by_customer, ->(adr_nr) { where(kund_adr_nr: adr_nr) }
  scope :for_display, -> { where(status: [ "draft", "ready" ]) }

  # Callbacks
  before_validation :set_defaults

  # Association Helper - optional, da Firebird-Items keine delivery_position haben
  def delivery_position
    @delivery_position ||= DeliveryPosition.find_by(liefschnr: liefschnr, posnr: posnr)
  end

  # Helper Methoden
  def position_id
    "#{liefschnr}-#{posnr}"
  end

  def customer_name
    # Versuche über delivery_position, sonst fallback
    delivery_position&.customer_name || "Kunde #{kund_adr_nr}"
  end

  def delivery_address
    # Versuche über delivery_position, sonst aus overrides oder fallback
    if unloading_address_override.present?
      unloading_address_override
    elsif delivery_position
      delivery_position.delivery_address
    else
      "Adresse #{werk_adr_nr}"
    end
  end

  def product_name
    bezeichnung || delivery_position&.product_name || artikel_nr || "Unbekanntes Produkt"
  end

  def weight_formatted
    return delivery_position.weight_formatted if delivery_position && menge.blank?
    return nil unless menge
    "#{calculated_weight.round(2)} kg"
  end

  def quantity_with_unit
    return delivery_position.quantity_with_unit if delivery_position && menge.blank?
    return nil unless menge
    "#{menge.to_i} #{einheit}"
  end

  def delivery_date
    beginn&.to_date || planned_date || delivery_position&.delivery&.datum
  end

  def vehicle
    vehicle_override || delivery_position&.delivery&.sales_order&.fahrzeug
  end

  def total_price
    (freight_price || 0) + (loading_price || 0) + (unloading_price || 0)
  end

  def loading_address
    if loading_address_override.present?
      loading_address_override
    elsif delivery_position&.delivery&.respond_to?(:loading_address)
      # Hole Ladeadresse aus Delivery wenn Methode vorhanden
      addr = delivery_position.delivery.loading_address
      addr ? "#{addr.strasse}, #{addr.plz} #{addr.ort}" : "Ladeadresse #{kund_adr_nr}"
    else
      # Fallback: Baue Adresse aus Delivery-Daten
      delivery = delivery_position&.delivery
      if delivery && delivery.respond_to?(:werk_adresse)
        werk = delivery.werk_adresse
        werk ? "#{werk.strasse}, #{werk.plz} #{werk.ort}" : "Ladeadresse #{kund_adr_nr}"
      else
        "Ladeadresse #{kund_adr_nr}"
      end
    end
  end

  def calculated_weight
    return 0 unless menge && einheit

    case einheit.upcase
    when "T", "TO"
      menge * 1000
    when "KG"
      menge
    when "SACK"
      menge * 25
    when "BB"
      menge * 600
    when "M³", "CBM"
      case typ
      when 1
        menge * 600  # Lose Ware
      else
        menge * 800  # Default
      end
    else
      0
    end
  end

  private

  def set_defaults
    self.status ||= "draft"
    self.gedruckt ||= 0
    self.plan_nr ||= 0
    self.kontrakt_nr ||= "0"
    self.invoiced ||= false
    self.typ ||= 0
    self.freight_price ||= 0.0
    self.loading_price ||= 0.0
    self.unloading_price ||= 0.0
  end
end
