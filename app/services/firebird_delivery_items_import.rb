# app/services/firebird_delivery_items_import.rb
class FirebirdDeliveryItemsImport
  def self.import!
    new.import!
  end

  def initialize
    @use_direct_connection = Rails.env.production?

    if @use_direct_connection
      @connection = Firebird::Connection.instance
      Rails.logger.info "Firebird: Direkte Verbindung (Production)"
    else
      Rails.logger.info "Firebird: HTTP API Verbindung (Development)"
    end
  end

  def import!
    Rails.logger.info "Starting Firebird import (#{@use_direct_connection ? 'direct' : 'HTTP API'})..."

    result = {
      imported: 0,
      updated: 0,
      skipped: 0,
      errors: []
    }

    begin
      delivery_notes = fetch_delivery_notes_from_firebird

      Rails.logger.info "#{delivery_notes.length} Lieferscheine gefunden"

      delivery_notes.each do |note|
        liefschnr = note["LIEFSCHNR"].to_i
        vauftragnr = note["VAUFTRAGNR"].to_i

        # Hole Auftragskopf-Daten aus WWS_VERKAUF1
        order_data = fetch_sales_order_from_firebird(vauftragnr)

        # Hole alle Positionen des Auftrags
        order_items = fetch_sales_order_items_from_firebird(vauftragnr)

        # Hole Lieferschein-Positionen
        items = fetch_delivery_items_from_firebird(liefschnr)

        items.each do |item|
          posnr = item["POSNR"].to_i

          # Finde passende Auftragsposition
          order_item_data = order_items.find { |oi| oi["POSNR"] == posnr } || {}

          import_result = import_item(item, note, order_data, order_item_data)

          case import_result
          when :imported
            result[:imported] += 1
          when :updated
            result[:updated] += 1
          when :skipped
            result[:skipped] += 1
          end
        rescue => e
          Rails.logger.error "Fehler beim Import von #{liefschnr}-#{item['POSNR']}: #{e.message}"
          result[:errors] << "#{liefschnr}-#{item['POSNR']}: #{e.message}"
        end
      end

      cleanup_obsolete_items(delivery_notes)

      Rails.logger.info "Import abgeschlossen: #{result[:imported]} neu, #{result[:updated]} aktualisiert, #{result[:skipped]} übersprungen"

    rescue => e
      Rails.logger.error "Firebird Import Fehler: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      result[:errors] << "Allgemeiner Fehler: #{e.message}"
    end

    result
  end

  private

  # ============================================
  # Fetch Methoden - Environment-abhängig
  # ============================================

  def fetch_delivery_notes_from_firebird
    if @use_direct_connection
      fetch_delivery_notes_direct
    else
      fetch_delivery_notes_api
    end
  end

  def fetch_delivery_items_from_firebird(liefschnr)
    if @use_direct_connection
      fetch_delivery_items_direct(liefschnr)
    else
      fetch_delivery_items_api(liefschnr)
    end
  end

  def fetch_sales_order_from_firebird(vauftragnr)
    return {} if vauftragnr.blank? || vauftragnr == "0"

    if @use_direct_connection
      fetch_sales_order_direct(vauftragnr)
    else
      fetch_sales_order_api(vauftragnr)
    end
  end

  def fetch_sales_order_items_from_firebird(vauftragnr)
    return [] if vauftragnr.blank? || vauftragnr == "0"

    if @use_direct_connection
      fetch_sales_order_items_direct(vauftragnr)
    else
      fetch_sales_order_items_api(vauftragnr)
    end
  end

  # ============================================
  # PRODUCTION: Direkte Firebird-Verbindung
  # ============================================

  def fetch_delivery_notes_direct
    sql = <<~SQL
      SELECT * FROM WWS_VLIEFER1#{' '}
      WHERE (GEDRUCKT = 'N' OR GEDRUCKT IS NULL)
        AND (SELBSTABHOLUNG = 'N' OR SELBSTABHOLUNG IS NULL)
      ORDER BY GEPLLIEFDATUM, KUNDNAME
    SQL

    @connection.query(sql)
  end

  def fetch_delivery_items_direct(liefschnr)
    # LIEFSCHNR ist ein Integer in Firebird
    sql = "SELECT * FROM WWS_VLIEFER2 WHERE LIEFSCHNR = #{liefschnr.to_i} ORDER BY POSNR"
    @connection.query(sql)
  end

  def fetch_sales_order_direct(vauftragnr)
    sql = "SELECT * FROM WWS_VERKAUF1 WHERE VAUFTRAGNR = #{vauftragnr.to_i}"
    results = @connection.query(sql)
    results.first || {}
  end

  def fetch_sales_order_items_direct(vauftragnr)
    sql = "SELECT * FROM WWS_VERKAUF2 WHERE VAUFTRAGNR = #{vauftragnr.to_i} ORDER BY POSNR"
    @connection.query(sql)
  end

  # ============================================
  # DEVELOPMENT: HTTP API Verbindung
  # ============================================

  def fetch_delivery_notes_api
    response = FirebirdConnectApi.get("/delivery_notes")

    if response.success?
      parsed = JSON.parse(response.body)
      # Konvertiere API-Format zu direktem Format (uppercase keys)
      (parsed["data"] || []).map { |row| normalize_keys(row) }
    else
      Rails.logger.error "Firebird API Fehler: #{response.code} - #{response.body}"
      []
    end
  end

  def fetch_delivery_items_api(liefschnr)
    response = FirebirdConnectApi.get("/delivery_notes/#{liefschnr}/items")

    if response.success?
      parsed = JSON.parse(response.body)
      (parsed["data"] || []).map { |row| normalize_keys(row) }
    else
      Rails.logger.error "Firebird API Fehler für Items #{liefschnr}: #{response.code}"
      []
    end
  end

  def fetch_sales_order_api(vauftragnr)
    response = FirebirdConnectApi.get("/sales_orders/#{vauftragnr}")

    if response.success?
      parsed = JSON.parse(response.body)
      normalize_keys(parsed["data"] || {})
    else
      Rails.logger.warn "Auftrag #{vauftragnr} nicht gefunden: #{response.code}"
      {}
    end
  end

  def fetch_sales_order_items_api(vauftragnr)
    response = FirebirdConnectApi.get("/sales_orders/#{vauftragnr}/items")

    if response.success?
      parsed = JSON.parse(response.body)
      (parsed["data"] || []).map { |row| normalize_keys(row) }
    else
      Rails.logger.warn "Auftragspositionen für #{vauftragnr} nicht gefunden: #{response.code}"
      []
    end
  end

  # Konvertiert API-Feldnamen zu Firebird-Feldnamen (uppercase)
  def normalize_keys(hash)
    return {} unless hash.is_a?(Hash)

    mapping = {
      "delivery_note_number" => "LIEFSCHNR",
      "sales_order_number" => "VAUFTRAGNR",
      "customer_number" => "KUNDENNR",
      "customer_name" => "KUNDNAME",
      "date" => "DATUM",
      "loading_date" => "LADEDATUM",
      "planned_delivery_date" => "GEPLLIEFDATUM",
      "delivery_address_number" => "LIEFADRNR",
      "billing_address_number" => "RECHNADRNR",
      "customer_address_number" => "KUNDADRNR",
      "vehicle_id" => "LKWNR",
      "vehicle_number" => "LKWNR",
      "operator" => "BEDIENER",
      "sales_rep" => "VERTRETER",
      "position" => "POSNR",
      "article_number" => "ARTIKELNR",
      "description_1" => "BEZEICHN1",
      "description_2" => "BEZEICHN2",
      "quantity" => "MENGE",
      "unit" => "EINHEIT",
      "unit_price" => "EINHPREIS",
      "net_amount" => "NETTO",
      "vat" => "MWST",
      "gross_amount" => "BRUTTO",
      "discount" => "RABATT",
      "weight" => "GEWICHT",
      "loading_weight" => "LADUNGSGEWICHT",
      "loading_location" => "LADEORT",
      "time" => "UHRZEIT",
      "vehicle_type" => "FAHRZEUG",
      "container_number" => "CONTAINERNR",
      "transport_type" => "TRANSPORTART",
      "forwarder_number" => "SPEDITEURNR",
      "license_plate_1" => "KFZKENNZEICHEN1",
      "license_plate_2" => "KFZKENNZEICHEN2",
      "delivery_type" => "LIEFERART",
      "info_general" => "INFOALLGEMEIN",
      "info_production" => "INFOPRODUKTION",
      "info_loading" => "INFOVERLADUNG",
      "info_delivery_note" => "INFOLIEFSCH",
      "delivery_text" => "LIEFERTEXT",
      "project" => "OBJEKT",
      "customer_order_number" => "BESTNRKD",
      "orderer" => "BESTELLER",
      "order_date" => "BESTDATUM",
      "status" => "AUFTSTATUS",
      "completed" => "ERLEDIGT",
      "position_type" => "POSART",
      "article_type" => "ARTIKELART",
      "long_text" => "LANGTEXT",
      "long_delivery" => "LANGLIEFER",
      "delivered_quantity" => "BISHLIEFMG",
      "unit_key" => "EINHSCHL",
      "price_unit" => "PREISEINH",
      "container_quantity" => "GEBINDEMG",
      "container_key" => "GEBINDSCHL",
      "container_unit" => "GEBINDEINH",
      "container_content" => "GEBINHALT",
      "pallet_count" => "PALANZAHL",
      "pallet_number" => "PALETTENNR",
      "list_price" => "LISTPREIS",
      "discount_type" => "RABATTART",
      "tax_key" => "STEUERSCHL",
      "vat_rate" => "MWSTSATZ",
      "warehouse" => "LAGER",
      "storage_bin" => "LAGERFACH",
      "batch_number" => "CHARGENNR",
      "serial_number" => "SERIENNR"
    }

    result = {}
    hash.each do |key, value|
      # Versuche Mapping, sonst uppercase
      new_key = mapping[key] || key.upcase
      result[new_key] = value
    end
    result
  end

  # ============================================
  # Import Methoden
  # ============================================

  def import_item(item_data, note_data, order_data, order_item_data)
    # LIEFSCHNR als String für PostgreSQL
    liefschnr = (item_data["LIEFSCHNR"] || note_data["LIEFSCHNR"]).to_s
    posnr = item_data["POSNR"].to_i

    if posnr <= 0
      Rails.logger.warn "⚠️ Überspringe Item mit ungültiger posnr: #{liefschnr}-#{posnr}"
      return :skipped
    end

    # Delivery/DeliveryPosition Tabellen liegen in Firebird, nicht in PostgreSQL
    # Wir erstellen nur UnassignedDeliveryItem in PostgreSQL

    # UnassignedDeliveryItem mit allen Feldern
    unassigned_item = UnassignedDeliveryItem.find_or_initialize_by(
      liefschnr: liefschnr,
      posnr: posnr
    )

    was_new = unassigned_item.new_record?

    unassigned_item.assign_attributes(
      build_unassigned_item_attributes(item_data, note_data, order_data, order_item_data)
    )

    unassigned_item.save!

    was_new ? :imported : :updated
  end

  def build_unassigned_item_attributes(item_data, note_data, order_data, order_item_data)
    {
      # Primärschlüssel
      vauftragnr: note_data["VAUFTRAGNR"],

      # Kundendaten
      kundennr: order_data["KUNDENNR"] || note_data["KUNDENNR"],
      kundname: clean_string(order_data["KUNDNAME"] || note_data["KUNDNAME"]),

      # Adressen
      kundadrnr: order_data["KUNDADRNR"],
      liefadrnr: order_data["LIEFADRNR"] || note_data["LIEFADRNR"],
      rechnadrnr: order_data["RECHNADRNR"] || note_data["RECHNADRNR"],
      ladeort: clean_string(order_data["LADEORT"]),

      # Termine Auftrag
      datum: order_data["DATUM"],
      geplliefdatum: order_data["GEPLLIEFDATUM"] || note_data["GEPLLIEFDATUM"],
      ladedatum: order_data["LADEDATUM"] || note_data["LADEDATUM"],
      ladetermin: order_data["LADETERMIN"],
      uhrzeit: clean_string(order_data["UHRZEIT"]),

      # Fahrzeug/Transport
      lkwnr: order_data["LKWNR"] || note_data["LKWNR"],
      fahrzeug: clean_string(order_data["FAHRZEUG"]),
      containernr: clean_string(order_data["CONTAINERNR"]),
      transportart: clean_string(order_data["TRANSPORTART"]),
      spediteurnr: order_data["SPEDITEURNR"],
      kfzkennzeichen1: clean_string(order_data["KFZKENNZEICHEN1"]),
      kfzkennzeichen2: clean_string(order_data["KFZKENNZEICHEN2"]),
      lieferart: clean_string(order_data["LIEFERART"]),

      # Infotexte
      infoallgemein: clean_string(order_data["INFOALLGEMEIN"]),
      infoproduktion: clean_string(order_data["INFOPRODUKTION"]),
      infoverladung: clean_string(order_data["INFOVERLADUNG"]),
      infoliefsch: clean_string(order_data["INFOLIEFSCH"]),
      liefertext: clean_string(order_data["LIEFERTEXT"]),

      # Projekt/Bestellung
      objekt: clean_string(order_data["OBJEKT"]),
      bestnrkd: clean_string(order_data["BESTNRKD"]),
      besteller: clean_string(order_data["BESTELLER"]),
      bestdatum: order_data["BESTDATUM"],

      # Bearbeiter
      bediener: clean_string(order_data["BEDIENER"] || note_data["BEDIENER"]),
      vertreter: clean_string(order_data["VERTRETER"] || note_data["VERTRETER"]),

      # Status aus Auftrag
      auftstatus: order_data["AUFTSTATUS"],
      erledigt: order_data["ERLEDIGT"] || false,

      # Artikeldaten
      posart: order_item_data["POSART"] || item_data["POSART"],
      artikelnr: clean_string(order_item_data["ARTIKELNR"] || item_data["ARTIKELNR"]),
      artikelart: clean_string(order_item_data["ARTIKELART"]),
      bezeichn1: clean_string(order_item_data["BEZEICHN1"] || item_data["BEZEICHN1"]),
      bezeichn2: clean_string(order_item_data["BEZEICHN2"] || item_data["BEZEICHN2"]),
      langtext: clean_string(order_item_data["LANGTEXT"]),
      langliefer: clean_string(order_item_data["LANGLIEFER"]),

      # Mengen
      menge: order_item_data["MENGE"] || item_data["LIEFMENGE"],
      bishliefmg: order_item_data["BISHLIEFMG"],
      einheit: clean_string(order_item_data["EINHEIT"] || item_data["EINHEIT"]),
      einhschl: clean_string(order_item_data["EINHSCHL"]),
      preiseinh: order_item_data["PREISEINH"],

      # Gebinde
      gebindemg: order_item_data["GEBINDEMG"],
      gebindschl: clean_string(order_item_data["GEBINDSCHL"]),
      gebindeinh: clean_string(order_item_data["GEBINDEINH"]),
      gebinhalt: order_item_data["GEBINHALT"],

      # Gewichte
      gewicht: order_item_data["GEWICHT"] || item_data["GEWICHT"],
      ladungsgewicht: order_item_data["LADUNGSGEWICHT"] || item_data["LADUNGSGEWICHT"],

      # Paletten
      palanzahl: order_item_data["PALANZAHL"],
      palettennr: clean_string(order_item_data["PALETTENNR"]),

      # Preise Original
      listpreis: order_item_data["LISTPREIS"],
      einhpreis: order_item_data["EINHPREIS"] || item_data["EINHPREIS"],
      netto: order_item_data["NETTO"] || item_data["NETTO"],
      mwst: order_item_data["MWST"] || item_data["MWST"],
      brutto: order_item_data["BRUTTO"] || item_data["BRUTTO"],
      rabatt: order_item_data["RABATT"] || item_data["RABATT"],
      rabattart: clean_string(order_item_data["RABATTART"]),
      steuerschl: clean_string(order_item_data["STEUERSCHL"]),
      mwstsatz: order_item_data["MWSTSATZ"],

      # Lager/Charge
      lager: clean_string(order_item_data["LAGER"]),
      lagerfach: clean_string(order_item_data["LAGERFACH"]),
      chargennr: clean_string(order_item_data["CHARGENNR"]),
      seriennr: clean_string(order_item_data["SERIENNR"]),

      # Planungsfelder
      planned_date: order_data["GEPLLIEFDATUM"] || note_data["GEPLLIEFDATUM"],
      planned_time: clean_string(order_data["UHRZEIT"]),
      status: "ready",
      tabelle_herkunft: "firebird_import",
      gedruckt: 0,
      plan_nr: 0,
      kontrakt_nr: "0",
      invoiced: false,
      typ: 0,
      freight_price: 0.0,
      loading_price: 0.0,
      unloading_price: 0.0
    }
  end

  def create_or_update_delivery(note_data, order_data)
    kundennr = note_data["KUNDENNR"]
    ensure_customer_exists(kundennr, note_data["KUNDNAME"])

    delivery = Delivery.find_or_initialize_by(
      liefschnr: note_data["LIEFSCHNR"].to_s.strip
    )

    delivery.assign_attributes(
      kundennr: kundennr,
      kundname: clean_string(note_data["KUNDNAME"]),
      datum: note_data["DATUM"],
      ladedatum: note_data["LADEDATUM"],
      geplliefdatum: note_data["GEPLLIEFDATUM"],
      vauftragnr: note_data["VAUFTRAGNR"]&.to_s || "0",
      liefadrnr: note_data["LIEFADRNR"],
      rechnadrnr: note_data["RECHNADRNR"],
      kundadrnr: note_data["KUNDADRNR"],
      gedruckt: false,
      selbstabholung: false,
      gutschrift: false,
      fruehbezug: false
    )

    delivery.save!
    Rails.logger.info "✓ Delivery erstellt/aktualisiert: #{delivery.liefschnr}"
    delivery
  rescue => e
    Rails.logger.error "✗ Fehler beim Erstellen von Delivery #{note_data['LIEFSCHNR']}: #{e.message}"
    nil
  end

  def ensure_customer_exists(kundennr, kundname)
    # Customer-Tabelle liegt in Firebird, nicht in PostgreSQL
    # Daher überspringen wir die Prüfung/Erstellung hier
    Rails.logger.debug "→ Customer #{kundennr} (#{kundname}) - Check übersprungen (Firebird-Tabelle)"
    true
  end

  def create_or_update_delivery_position(item_data, note_data, order_item_data)
    liefschnr = (item_data["LIEFSCHNR"] || note_data["LIEFSCHNR"]).to_s.strip

    position = DeliveryPosition.find_or_initialize_by(
      liefschnr: liefschnr,
      posnr: item_data["POSNR"].to_i
    )

    position.assign_attributes(
      artikelnr: clean_string(item_data["ARTIKELNR"]) || "UNKNOWN",
      bezeichn1: clean_string(item_data["BEZEICHN1"]) || "Aus Firebird importiert",
      bezeichn2: clean_string(item_data["BEZEICHN2"] || order_item_data["BEZEICHN2"]),
      liefmenge: item_data["LIEFMENGE"] || 0,
      einheit: clean_string(item_data["EINHEIT"]) || "ST",
      gewicht: order_item_data["GEWICHT"] || item_data["GEWICHT"],
      ladungsgewicht: order_item_data["LADUNGSGEWICHT"] || item_data["LADUNGSGEWICHT"],
      tour_id: nil,
      sequence_number: nil
    )

    position.save!
  rescue => e
    Rails.logger.error "✗ Fehler beim Erstellen von DeliveryPosition: #{e.message}"
    raise
  end

  def cleanup_obsolete_items(current_delivery_notes)
    current_liefschnrs = current_delivery_notes.map { |note| note["LIEFSCHNR"].to_s.strip }

    obsolete_items = UnassignedDeliveryItem
                       .where(status: [ "draft", "ready" ])
                       .where(tabelle_herkunft: "firebird_import")
                       .where.not(liefschnr: current_liefschnrs)

    obsolete_count = obsolete_items.count
    obsolete_items.destroy_all if obsolete_count > 0
  end

  # ============================================
  # Helper Methoden
  # ============================================

  def clean_string(value)
    return nil if value.nil?
    value.to_s.strip.presence
  end

  def escape_sql(value)
    value.to_s.gsub("'", "''")
  end
end
