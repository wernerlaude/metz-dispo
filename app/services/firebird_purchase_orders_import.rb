# app/services/firebird_purchase_orders_import.rb
#
# Importiert Bestellungen (Abholungen) aus Firebird in UnassignedDeliveryItem
# mit typ = 1 (pickup)
#
class FirebirdPurchaseOrdersImport
  # Typ-Konstanten (entspricht enum im Model)
  TYP_DELIVERY = 0
  TYP_PICKUP = 1

  class << self
    def import!
      new.import!
    end
  end

  def initialize
    @imported = 0
    @updated = 0
    @skipped = 0
    @processed_ids = []
  end

  def import!
    Rails.logger.info "Starting Purchase Orders import..."

    if use_api?
      Rails.logger.info "Firebird: HTTP API Verbindung"
      import_via_api
    else
      Rails.logger.info "Firebird: Direkte Verbindung"
      import_via_direct_connection
    end

    cleanup_obsolete_items

    result = { imported: @imported, updated: @updated, skipped: @skipped }
    Rails.logger.info "Pickup-Import abgeschlossen: #{@imported} neu, #{@updated} aktualisiert, #{@skipped} übersprungen"
    result
  end

  private

  def can_use_direct_connection?
    defined?(Firebird::Connection) && Firebird::Connection.instance.present?
  rescue
    false
  end

  def use_api?
    !can_use_direct_connection?
  end

  # ============================================
  # API-basierter Import (Development)
  # ============================================

  def import_via_api
    purchase_orders = fetch_purchase_orders_from_api
    Rails.logger.info "#{purchase_orders.length} Bestellungen gefunden"

    purchase_orders.each do |po|
      po_number = po["purchase_order_number"]
      items = fetch_purchase_order_items_from_api(po_number)

      Rails.logger.info "Bestellung #{po_number}: #{items.length} Positionen"

      items.each do |item|
        import_item(po, item)
      end
    end
  end

  def fetch_purchase_orders_from_api
    response = FirebirdConnectApi.get("/purchase_orders/pending")

    if response.success?
      parsed = JSON.parse(response.body)
      parsed["data"] || []
    else
      Rails.logger.error "API Fehler beim Laden der Bestellungen: #{response.code}"
      []
    end
  rescue => e
    Rails.logger.error "API Fehler: #{e.message}"
    []
  end

  def fetch_purchase_order_items_from_api(po_number)
    response = FirebirdConnectApi.get("/purchase_orders/#{po_number}/items")

    if response.success?
      parsed = JSON.parse(response.body)
      parsed["data"] || []
    else
      Rails.logger.warn "Positionen für Bestellung #{po_number} nicht gefunden: #{response.code}"
      []
    end
  rescue => e
    Rails.logger.warn "API Fehler bei Positionen #{po_number}: #{e.message}"
    []
  end

  # ============================================
  # Direkter Import (Production)
  # ============================================

  def import_via_direct_connection
    purchase_orders = fetch_purchase_orders_direct
    Rails.logger.info "#{purchase_orders.length} Bestellungen gefunden"

    purchase_orders.each do |po_row|
      po_number = po_row["BESTELLNR"]
      items = fetch_purchase_order_items_direct(po_number)

      Rails.logger.info "Bestellung #{po_number}: #{items.length} Positionen"

      items.each do |item_row|
        import_item_direct(po_row, item_row)
      end
    end
  end

  def fetch_purchase_orders_direct
    connection = Firebird::Connection.instance
    sql = <<~SQL
      SELECT * FROM WWS_BESTELLUNG1
      WHERE ERLEDIGT = 'N' OR ERLEDIGT IS NULL
      ORDER BY LIEFERTAG ASC, BESTELLNR ASC
    SQL
    connection.query(sql)
  end

  def fetch_purchase_order_items_direct(po_number)
    connection = Firebird::Connection.instance
    sql = <<~SQL
      SELECT * FROM WWS_BESTELLUNG2
      WHERE BESTELLNR = #{po_number.to_i}
      ORDER BY POSNR
    SQL
    connection.query(sql)
  end

  # ============================================
  # Import-Logik
  # ============================================

  def import_item(po, item)
    # Für Pickups: bestellnr als liefschnr verwenden (mit Prefix "P")
    bestellnr = po["purchase_order_number"].to_s
    posnr = item["position"].to_i

    # Eindeutige ID für Pickups: P + Bestellnummer
    pickup_id = "P#{bestellnr}"

    @processed_ids << "#{pickup_id}-#{posnr}"

    existing = UnassignedDeliveryItem.find_by(liefschnr: pickup_id, posnr: posnr)

    attributes = build_attributes_from_api(po, item, pickup_id)

    if existing
      existing.update!(attributes)
      @updated += 1
    else
      UnassignedDeliveryItem.create!(attributes)
      @imported += 1
    end
  rescue => e
    Rails.logger.error "Fehler beim Import von Bestellung #{po["purchase_order_number"]}-#{item["position"]}: #{e.message}"
    @skipped += 1
  end

  def import_item_direct(po_row, item_row)
    bestellnr = po_row["BESTELLNR"].to_s
    posnr = item_row["POSNR"].to_i

    pickup_id = "P#{bestellnr}"

    @processed_ids << "#{pickup_id}-#{posnr}"

    existing = UnassignedDeliveryItem.find_by(liefschnr: pickup_id, posnr: posnr)

    attributes = build_attributes_from_direct(po_row, item_row, pickup_id)

    if existing
      existing.update!(attributes)
      @updated += 1
    else
      UnassignedDeliveryItem.create!(attributes)
      @imported += 1
    end
  rescue => e
    Rails.logger.error "Fehler beim Import von Bestellung #{po_row["BESTELLNR"]}-#{item_row["POSNR"]}: #{e.message}"
    @skipped += 1
  end

  def build_attributes_from_api(po, item, pickup_id)
    {
      # Identifikation
      liefschnr: pickup_id,
      posnr: item["position"].to_i,
      bestellnr: po["purchase_order_number"].to_s,

      # Lieferant als "Kunde" für Abholung
      lieferantnr: po["supplier_number"],
      liefname: po["supplier_name"],
      kundennr: po["supplier_number"],
      kundname: po["supplier_name"],
      kundadrnr: po["supplier_address_number"],
      liefadrnr: po["supplier_address_number"],

      # Artikel
      artikelnr: item["article_number"],
      bezeichn1: item["description_1"],
      bezeichn2: item["description_2"],
      menge: item["quantity"],
      einheit: item["unit"],
      gewicht: item["weight"],

      # Preise
      brutto: item["amount"],
      netto: item["amount"],

      # Planung
      geplliefdatum: parse_date(po["delivery_date"]) || parse_date(item["delivery_date"]),
      uhrzeit: po["time"],

      # Zusatzinfos
      infoallgemein: [ po["text_1"], po["text_2"] ].compact.reject(&:blank?).join(" / "),

      # Typ und Status
      typ: TYP_PICKUP,
      status: "open",
      tabelle_herkunft: "firebird_import"
    }
  end

  def build_attributes_from_direct(po_row, item_row, pickup_id)
    {
      # Identifikation
      liefschnr: pickup_id,
      posnr: item_row["POSNR"].to_i,
      bestellnr: po_row["BESTELLNR"].to_s,

      # Lieferant als "Kunde" für Abholung
      lieferantnr: po_row["LIEFERANTNR"],
      liefname: clean_encoding(po_row["LIEFNAME"]),
      kundennr: po_row["LIEFERANTNR"],
      kundname: clean_encoding(po_row["LIEFNAME"]),
      kundadrnr: po_row["LIEFADRNR"],
      liefadrnr: po_row["LIEFADRNR"],

      # Artikel
      artikelnr: item_row["ARTIKELNR"]&.strip,
      bezeichn1: clean_encoding(item_row["BEZEICHN1"]),
      bezeichn2: clean_encoding(item_row["BEZEICHN2"]),
      menge: item_row["MENGE"],
      einheit: item_row["EINHEIT"]&.strip,
      gewicht: item_row["GEWICHT"],

      # Preise
      brutto: item_row["BETRAG"],
      netto: item_row["BETRAG"],

      # Planung
      geplliefdatum: po_row["LIEFERTAG"] || item_row["LIEFERTAG"],
      uhrzeit: po_row["UHRZEIT"]&.strip,

      # Zusatzinfos
      infoallgemein: [ clean_encoding(po_row["TEXT1"]), clean_encoding(po_row["TEXT2"]) ].compact.reject(&:blank?).join(" / "),

      # Typ und Status
      typ: TYP_PICKUP,
      status: "open",
      tabelle_herkunft: "firebird_import"
    }
  end

  def cleanup_obsolete_items
    return if @processed_ids.empty?

    # Nur Pickup-Items bereinigen (typ = 1 = pickup)
    obsolete_count = UnassignedDeliveryItem
                       .where(status: "open")
                       .where(tabelle_herkunft: "firebird_import")
                       .where(typ: TYP_PICKUP)
                       .where.not(liefschnr: @processed_ids.map { |id| id.split("-").first }.uniq)
                       .count

    Rails.logger.info "Cleanup: #{obsolete_count} obsolete Pickup-Items gefunden"
  end

  def parse_date(value)
    return nil if value.blank?
    Date.parse(value.to_s)
  rescue
    nil
  end

  def clean_encoding(value)
    return nil if value.nil?
    value.to_s.encode("UTF-8", invalid: :replace, undef: :replace, replace: "").strip
  end
end
