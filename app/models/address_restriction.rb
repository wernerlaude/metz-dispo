class AddressRestriction < ApplicationRecord
  belongs_to :driver

  validates :driver_id, presence: true
  validates :liefadrnr, presence: true
  validates :liefadrnr, uniqueness: { scope: :driver_id, message: "ist für diesen Fahrer bereits gesperrt" }

  def address_display_name
    # Erst in UnassignedDeliveryItem suchen
    item = UnassignedDeliveryItem.find_by(liefadrnr: liefadrnr)
    if item && (item.kundname.present? || item.liefname.present?)
      parts = []
      parts << item.kundname if item.kundname.present?
      parts << item.liefname if item.liefname.present? && item.liefname != item.kundname
      return parts.join(" - ")
    end

    # Sonst direkt aus Firebird laden
    address = load_address_from_source
    if address
      parts = [ address[:name1], address[:ort] ].compact.reject(&:blank?)
      return parts.join(" - ") if parts.any?
    end

    "Adresse #{liefadrnr}"
  end

  def to_s
    "#{driver.full_name} - #{address_display_name}"
  end

  private

  def load_address_from_source
    if use_direct_connection?
      load_address_from_firebird
    else
      load_address_from_api
    end
  end

  def use_direct_connection?
    defined?(Firebird::Connection) && Firebird::Connection.instance.present?
  rescue
    false
  end

  def load_address_from_api
    return nil unless defined?(FirebirdConnectApi)

    response = FirebirdConnectApi.get("/addresses/#{liefadrnr}")
    if response.success?
      data = JSON.parse(response.body)["data"]
      if data
        {
          name1: data["name_1"],
          name2: data["name_2"],
          strasse: data["street"],
          plz: data["postal_code"],
          ort: data["city"]
        }
      end
    end
  rescue => e
    Rails.logger.warn "API Adresse #{liefadrnr} Fehler: #{e.message}"
    nil
  end

  def load_address_from_firebird
    return nil unless defined?(Firebird::Connection)

    conn = Firebird::Connection.instance
    rows = conn.query("SELECT * FROM ADRESSEN WHERE NUMMER = #{liefadrnr.to_i}")

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
    Rails.logger.warn "Firebird Adresse #{liefadrnr} nicht gefunden: #{e.message}"
    nil
  end

  def clean_encoding(value)
    return nil if value.nil?
    value.to_s.force_encoding("UTF-8").encode("UTF-8", invalid: :replace, undef: :replace, replace: "").strip
  end
end
