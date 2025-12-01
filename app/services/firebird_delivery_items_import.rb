# app/services/firebird_delivery_items_import.rb
class FirebirdDeliveryItemsImport
  def self.import!
    new.import!
  end

  def initialize
    @use_direct_connection = can_use_direct_connection?

    if @use_direct_connection
      @connection = Firebird::Connection.instance
      Rails.logger.info "Firebird: Direkte Verbindung"
    else
      Rails.logger.info "Firebird: HTTP API Verbindung"
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
      # Hole ALLE Lieferscheine direkt aus WWS_VLIEFER1
      delivery_notes = fetch_delivery_notes_from_firebird

      Rails.logger.info "#{delivery_notes.length} Lieferscheine gefunden"

      delivery_notes.each do |note|
        liefschnr = note["LIEFSCHNR"].to_i
        vauftragnr = note["VAUFTRAGNR"].to_i

        # Hole Auftragskopf-Daten aus WWS_VERKAUF1 (falls vorhanden)
        order_data = fetch_sales_order_from_firebird(vauftragnr)

        # Hole alle Positionen des Auftrags (falls vorhanden)
        order_items = fetch_sales_order_items_from_firebird(vauftragnr)

        # Hole Lieferschein-Positionen aus WWS_VLIEFER2
        items = fetch_delivery_items_from_firebird(liefschnr)

        Rails.logger.info "Lieferschein #{liefschnr}: #{items.length} Positionen"

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

  def can_use_direct_connection?
    defined?(Firebird::Connection) && Firebird::Connection.instance.present?
  rescue
    false
  end

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
    return {} if vauftragnr.blank? || vauftragnr == 0

    if @use_direct_connection
      fetch_sales_order_direct(vauftragnr)
    else
      fetch_sales_order_api(vauftragnr)
    end
  end

  def fetch_sales_order_items_from_firebird(vauftragnr)
    return [] if vauftragnr.blank? || vauftragnr == 0

    if @use_direct_connection
      fetch_sales_order_items_direct(vauftragnr)
    else
      fetch_sales_order_items_api(vauftragnr)
    end
  end

  # ============================================
  # PRODUCTION: Direkte Firebird-Verbindung
  # ============================================

  # ALLE Lieferscheine ohne Filter
  def fetch_delivery_notes_direct
    sql = <<~SQL
      SELECT * FROM WWS_VLIEFER1 
         WHERE AUFTSTATUS = 2 AND ERLEDIGT = 'N'
      ORDER BY GEPLLIEFDATUM, KUNDNAME
    SQL

    @connection.query(sql)
  end

  def fetch_delivery_items_direct(liefschnr)
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

  # ALLE Lieferscheine ohne Filter
  def fetch_delivery_notes_api
    response = FirebirdConnectApi.get("/delivery_notes")

    if response.success?
      parsed = JSON.parse(response.body)
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
      "position_type" => "POSART",
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
      "time" => "UHRZEIT"
    }

    result = {}
    hash.each do |key, value|
      new_key = mapping[key] || key.upcase
      result[new_key] = value
    end
    result
  end

  # ============================================
  # Import Methoden
  # ============================================

  def import_item(item_data, note_data, order_data, order_item_data)
    liefschnr = (item_data["LIEFSCHNR"] || note_data["LIEFSCHNR"]).to_s
    posnr = item_data["POSNR"].to_i

    if posnr <= 0
      Rails.logger.warn "⚠️ Überspringe Item mit ungültiger posnr: #{liefschnr}-#{posnr}"
      return :skipped
    end

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
      vauftragnr: note_data["VAUFTRAGNR"],
      kundennr: order_data["KUNDENNR"] || note_data["KUNDENNR"],
      kundname: clean_string(order_data["KUNDNAME"] || note_data["KUNDNAME"]),
      kundadrnr: order_data["KUNDADRNR"],
      liefadrnr: order_data["LIEFADRNR"] || note_data["LIEFADRNR"],
      rechnadrnr: order_data["RECHNADRNR"] || note_data["RECHNADRNR"],
      ladeort: clean_string(order_data["LADEORT"] || note_data["LADEORT"]),
      datum: order_data["DATUM"],
      geplliefdatum: order_data["GEPLLIEFDATUM"] || note_data["GEPLLIEFDATUM"],
      ladedatum: order_data["LADEDATUM"] || note_data["LADEDATUM"],
      ladetermin: order_data["LADETERMIN"],
      uhrzeit: clean_string(order_data["UHRZEIT"]),
      lkwnr: order_data["LKWNR"] || note_data["LKWNR"],
      fahrzeug: clean_string(order_data["FAHRZEUG"]),
      containernr: clean_string(order_data["CONTAINERNR"]),
      transportart: clean_string(order_data["TRANSPORTART"]),
      spediteurnr: order_data["SPEDITEURNR"],
      kfzkennzeichen1: clean_string(order_data["KFZKENNZEICHEN1"]),
      kfzkennzeichen2: clean_string(order_data["KFZKENNZEICHEN2"]),
      lieferart: clean_string(order_data["LIEFERART"]),
      infoallgemein: clean_string(order_data["INFOALLGEMEIN"]),
      infoproduktion: clean_string(order_data["INFOPRODUKTION"]),
      infoverladung: clean_string(order_data["INFOVERLADUNG"]),
      infoliefsch: clean_string(order_data["INFOLIEFSCH"]),
      liefertext: clean_string(order_data["LIEFERTEXT"]),
      objekt: clean_string(order_data["OBJEKT"]),
      bestnrkd: clean_string(order_data["BESTNRKD"]),
      besteller: clean_string(order_data["BESTELLER"]),
      bestdatum: order_data["BESTDATUM"],
      bediener: clean_string(order_data["BEDIENER"] || note_data["BEDIENER"]),
      vertreter: clean_string(order_data["VERTRETER"] || note_data["VERTRETER"]),
      auftstatus: order_data["AUFTSTATUS"],
      erledigt: order_data["ERLEDIGT"] || false,
      posart: order_item_data["POSART"] || item_data["POSART"],
      artikelnr: clean_string(order_item_data["ARTIKELNR"] || item_data["ARTIKELNR"]),
      artikelart: clean_string(order_item_data["ARTIKELART"]),
      bezeichn1: clean_string(order_item_data["BEZEICHN1"] || item_data["BEZEICHN1"]),
      bezeichn2: clean_string(order_item_data["BEZEICHN2"] || item_data["BEZEICHN2"]),
      langtext: clean_string(order_item_data["LANGTEXT"]),
      langliefer: clean_string(order_item_data["LANGLIEFER"]),
      menge: order_item_data["MENGE"] || item_data["MENGE"] || item_data["LIEFMENGE"],
      bishliefmg: order_item_data["BISHLIEFMG"],
      einheit: clean_string(order_item_data["EINHEIT"] || item_data["EINHEIT"]),
      einhschl: clean_string(order_item_data["EINHSCHL"]),
      preiseinh: order_item_data["PREISEINH"],
      gebindemg: order_item_data["GEBINDEMG"],
      gebindschl: clean_string(order_item_data["GEBINDSCHL"]),
      gebindeinh: clean_string(order_item_data["GEBINDEINH"]),
      gebinhalt: order_item_data["GEBINHALT"],
      gewicht: order_item_data["GEWICHT"] || item_data["GEWICHT"],
      ladungsgewicht: order_item_data["LADUNGSGEWICHT"] || item_data["LADUNGSGEWICHT"],
      palanzahl: order_item_data["PALANZAHL"],
      palettennr: clean_string(order_item_data["PALETTENNR"]),
      listpreis: order_item_data["LISTPREIS"],
      einhpreis: order_item_data["EINHPREIS"] || item_data["EINHPREIS"],
      netto: order_item_data["NETTO"] || item_data["NETTO"],
      mwst: order_item_data["MWST"] || item_data["MWST"],
      brutto: order_item_data["BRUTTO"] || item_data["BRUTTO"],
      rabatt: order_item_data["RABATT"] || item_data["RABATT"],
      rabattart: clean_string(order_item_data["RABATTART"]),
      steuerschl: clean_string(order_item_data["STEUERSCHL"]),
      mwstsatz: order_item_data["MWSTSATZ"],
      lager: clean_string(order_item_data["LAGER"]),
      lagerfach: clean_string(order_item_data["LAGERFACH"]),
      chargennr: clean_string(order_item_data["CHARGENNR"]),
      seriennr: clean_string(order_item_data["SERIENNR"]),
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

  def cleanup_obsolete_items(current_delivery_notes)
    return if current_delivery_notes.empty?

    current_liefschnrs = current_delivery_notes.map { |note| note["LIEFSCHNR"].to_s }

    obsolete_items = UnassignedDeliveryItem
                       .where(status: %w[draft ready])
                       .where(tabelle_herkunft: "firebird_import")
                       .where.not(liefschnr: current_liefschnrs)

    obsolete_count = obsolete_items.count
    Rails.logger.info "Cleanup: #{obsolete_count} obsolete Items gefunden"
    obsolete_items.destroy_all if obsolete_count > 0
  end

  def clean_string(value)
    return nil if value.nil?
    value.to_s.encode("UTF-8", invalid: :replace, undef: :replace, replace: "").strip.presence
  end

  def escape_sql(value)
    value.to_s.gsub("'", "''")
  end
end
