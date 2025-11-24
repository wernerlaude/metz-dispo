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
  scope :by_customer, ->(adr_nr) { where(kundadrnr: adr_nr) }
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
    # Nutze importierte Daten, dann fallback auf delivery_position
    kundname.presence || delivery_position&.customer_name || "Kunde #{kundennr}"
  end

  def delivery_address
    # Nutze liefadrnr für die Lieferadresse
    if liefadrnr.present?
      # Versuche Adresse zu laden
      address = load_address(liefadrnr)
      return format_address(address) if address
    end

    # Fallback auf delivery_position
    if delivery_position
      delivery_position.delivery_address
    else
      "Adresse #{liefadrnr || kundadrnr}"
    end
  end

  def loading_address
    # Nutze ladeort für die Ladeadresse
    return ladeort if ladeort.present?

    # Fallback auf delivery_position
    if delivery_position&.delivery&.respond_to?(:loading_address)
      addr = delivery_position.delivery.loading_address
      return format_address(addr) if addr
    end

    "Ladeadresse #{kundadrnr}"
  end

  def product_name
    # Kombiniere bezeichn1 und bezeichn2
    name = bezeichn1.presence || artikel_nr || "Unbekanntes Produkt"
    name += " - #{bezeichn2}" if bezeichn2.present?
    name
  end

  def weight_formatted
    # Nutze importiertes Gewicht, sonst berechne
    if gewicht.present? && gewicht > 0
      "#{gewicht.round(2)} kg"
    elsif ladungsgewicht.present? && ladungsgewicht > 0
      "#{ladungsgewicht.round(2)} kg"
    elsif menge.present?
      "#{calculated_weight.round(2)} kg"
    else
      delivery_position&.weight_formatted
    end
  end

  def quantity_with_unit
    return nil unless menge.present?

    quantity_str = menge.to_i.to_s
    unit_str = einheit.presence || "ST"

    # Füge Gebinde-Info hinzu wenn vorhanden
    if gebinhalt.present? && gebinhalt > 0
      "#{quantity_str} #{unit_str} (#{gebinhalt} #{gebindeinh})"
    else
      "#{quantity_str} #{unit_str}"
    end
  end

  def delivery_date
    geplliefdatum || planned_date || beginn&.to_date || delivery_position&.delivery&.datum
  end

  def vehicle
    vehicle_override.presence || lkwnr.presence || fahrzeug.presence
  end

  def total_price
    (freight_price || 0) + (loading_price || 0) + (unloading_price || 0)
  end

  def calculated_weight
    return 0 unless menge && einheit

    case einheit.to_s.upcase
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

  # Zusätzliche Helper für die neuen Felder
  def full_info_text
    [ infoallgemein, infoverladung, infoliefsch ].compact.reject(&:blank?).join("\n")
  end

  def order_reference
    bestnrkd.presence || vauftragnr
  end

  def project_name
    objekt
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

  def load_address(address_nr)
    return nil unless address_nr.present?

    # Versuche über ActiveRecord
    begin
      Address.find_by(nummer: address_nr)
    rescue
      nil
    end
  end

  def format_address(address)
    return nil unless address

    if address.respond_to?(:strasse)
      "#{address.strasse}, #{address.plz} #{address.ort}"
    elsif address.is_a?(Hash)
      "#{address[:strasse]}, #{address[:plz]} #{address[:ort]}"
    else
      address.to_s
    end
  end
end
