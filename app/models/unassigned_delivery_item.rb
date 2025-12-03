# app/models/unassigned_delivery_item.rb
class UnassignedDeliveryItem < ApplicationRecord
  # Tour-Association
  belongs_to :tour, optional: true

  # Validierungen
  validates :liefschnr, presence: true
  validates :posnr, presence: true
  validates :status, presence: true, inclusion: { in: %w[draft ready planned assigned completed cancelled] }

  # Scopes
  scope :draft, -> { where(status: "draft") }
  scope :ready, -> { where(status: "ready") }
  scope :planned, -> { where(status: "planned") }
  scope :assigned, -> { where(status: "assigned") }
  scope :not_invoiced, -> { where(invoiced: false) }
  scope :from_firebird, -> { where(tabelle_herkunft: "firebird_import") }
  scope :by_planned_date, -> { order(planned_date: :asc) }
  scope :by_customer, ->(adr_nr) { where(kundadrnr: adr_nr) }
  scope :for_display, -> { where(status: [ "draft", "ready" ]) }
  scope :unassigned, -> { where(tour_id: nil).where(status: [ "draft", "ready" ]) }
  scope :by_tour, ->(tour) { where(tour: tour) }

  # Callbacks
  before_validation :set_defaults

  enum :typ, { delivery: 0, pickup: 1 }, default: :delivery

  # Helper Methoden
  def position_id
    "#{liefschnr}-#{posnr}"
  end

  def customer_name
    kundname.presence || "Kunde #{kundennr}"
  end

  def delivery_address
    if liefadrnr.present?
      address = load_address(liefadrnr)
      return format_address(address) if address
    end
    "Adresse #{liefadrnr || kundadrnr}"
  end

  def loading_address
    return ladeort if ladeort.present?
    "Ladeadresse #{kundadrnr}"
  end

  def product_name
    name = bezeichn1.presence || artikelnr || "Unbekanntes Produkt"
    name += " - #{bezeichn2}" if bezeichn2.present?
    name
  end

  def weight_formatted
    if gewicht.present? && gewicht > 0
      "#{gewicht.round(2)} kg"
    elsif ladungsgewicht.present? && ladungsgewicht > 0
      "#{ladungsgewicht.round(2)} kg"
    elsif menge.present?
      "#{calculated_weight.round(2)} kg"
    else
      "0 kg"
    end
  end

  def quantity_with_unit
    return nil unless menge.present?

    quantity_str = menge.to_i.to_s
    unit_str = einheit.presence || "ST"

    if gebinhalt.present? && gebinhalt > 0
      "#{quantity_str} #{unit_str} (#{gebinhalt} #{gebindeinh})"
    else
      "#{quantity_str} #{unit_str}"
    end
  end

  def delivery_date
    geplliefdatum # || planned_date
  end

  def vehicle
    lkwnr.presence || fahrzeug.presence
  end

  def total_price
    (menge || 0) * (netto || 0)
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
      menge * 800
    else
      0
    end
  end

  def full_info_text
    [ infoallgemein, infoverladung, infoliefsch ].compact.reject(&:blank?).join("\n")
  end

  def order_reference
    bestnrkd.presence || vauftragnr
  end

  def project_name
    objekt
  end

  # Für Kompatibilität mit altem Code der DeliveryPosition erwartet
  def liefmenge
    menge
  end

  # Delivery-Daten aus Firebird laden (für Kompatibilität)
  def delivery
    @delivery ||= load_delivery_data
  end

  private

  def set_defaults
    self.status ||= "draft"
    self.gedruckt ||= 0
    self.plan_nr ||= 0
    self.kontrakt_nr ||= "0"
    self.invoiced ||= false
    self.typ ||= 0
  end

  # ============================================
  # Adress-Loading: API oder Direkt
  # ============================================

  def load_address(address_nr)
    return nil unless address_nr.present?

    if use_direct_connection?
      load_address_from_firebird(address_nr)
    else
      load_address_from_api(address_nr)
    end
  end

  def use_direct_connection?
    defined?(Firebird::Connection) && Firebird::Connection.instance.present?
  rescue
    false
  end

  # HTTP API Methode
  def load_address_from_api(address_nr)
    return nil unless defined?(FirebirdConnectApi)

    response = FirebirdConnectApi.get("/addresses/#{address_nr}")

    if response.success?
      parsed = JSON.parse(response.body)
      data = parsed["data"]

      if data
        {
          name1: data["name_1"],
          name2: data["name_2"],
          strasse: data["street"],
          plz: data["postal_code"],
          ort: data["city"]
        }
      end
    else
      Rails.logger.warn "API Adresse #{address_nr} nicht gefunden: #{response.code}"
      nil
    end
  rescue => e
    Rails.logger.warn "API Adresse #{address_nr} Fehler: #{e.message}"
    nil
  end

  # Direkte Firebird-Verbindung (Production)
  def load_address_from_firebird(address_nr)
    return nil unless address_nr.present?
    return nil unless defined?(Firebird::Connection)

    begin
      conn = Firebird::Connection.instance
      rows = conn.query("SELECT * FROM ADRESSEN WHERE NUMMER = #{address_nr.to_i}")

      if rows.any?
        row = rows.first
        {
          name1: clean_encoding(row["NAME1"]),
          name2: clean_encoding(row["NAME2"]),
          strasse: clean_encoding(row["STRASSE"]),
          plz: clean_encoding(row["PLZ"]),
          ort: clean_encoding(row["ORT"])
        }
      end
    rescue => e
      Rails.logger.warn "Firebird Adresse #{address_nr} nicht gefunden: #{e.message}"
      nil
    end
  end

  def load_delivery_data
    if use_direct_connection?
      load_delivery_from_firebird
    else
      load_delivery_from_api
    end
  end

  # HTTP API Methode für Delivery
  def load_delivery_from_api
    return nil unless defined?(FirebirdConnectApi)

    response = FirebirdConnectApi.get("/delivery_notes/#{liefschnr}")

    if response.success?
      parsed = JSON.parse(response.body)
      data = parsed["data"]

      if data
        OpenStruct.new(
          liefschnr: data["delivery_note_number"],
          kundennr: data["customer_number"],
          kundname: data["customer_name"],
          liefadrnr: data["delivery_address_number"],
          kundadrnr: data["customer_address_number"],
          ladedatum: data["loading_date"],
          geplliefdatum: data["planned_delivery_date"],
          selbstabholung: false,
          fruehbezug: false,
          gutschrift: false,
          customer_name: data["customer_name"],
          formatted_address: "Lieferadresse #{data['delivery_address_number']}"
        )
      end
    else
      Rails.logger.warn "API Delivery #{liefschnr} nicht gefunden: #{response.code}"
      nil
    end
  rescue => e
    Rails.logger.warn "API Delivery #{liefschnr} Fehler: #{e.message}"
    nil
  end

  # Direkte Firebird-Verbindung (Production)
  def load_delivery_from_firebird
    return nil unless defined?(Firebird::Connection)

    begin
      conn = Firebird::Connection.instance
      rows = conn.query("SELECT * FROM WWS_VLIEFER1 WHERE LIEFSCHNR = #{liefschnr.to_i}")

      if rows.any?
        row = rows.first
        OpenStruct.new(
          liefschnr: row["LIEFSCHNR"],
          kundennr: row["KUNDENNR"],
          kundname: clean_encoding(row["KUNDNAME"]),
          liefadrnr: row["LIEFADRNR"],
          kundadrnr: row["KUNDADRNR"],
          ladedatum: row["LADEDATUM"],
          geplliefdatum: row["GEPLLIEFDATUM"],
          selbstabholung: row["SELBSTABHOLUNG"] == "J",
          fruehbezug: row["FRUEHBEZUG"] == "J",
          gutschrift: row["GUTSCHRIFT"] == "J",
          customer_name: clean_encoding(row["KUNDNAME"]),
          formatted_address: "Lieferadresse #{row['LIEFADRNR']}"
        )
      end
    rescue => e
      Rails.logger.warn "Firebird Delivery nicht gefunden: #{e.message}"
      nil
    end
  end

  def format_address(address)
    return nil unless address

    if address.is_a?(Hash)
      parts = [ address[:strasse], "#{address[:plz]} #{address[:ort]}" ].compact.reject(&:blank?)
      parts.join(", ")
    else
      address.to_s
    end
  end

  def clean_encoding(value)
    return nil if value.nil?
    value.to_s.force_encoding("UTF-8").encode("UTF-8", invalid: :replace, undef: :replace, replace: "").strip
  end
end
