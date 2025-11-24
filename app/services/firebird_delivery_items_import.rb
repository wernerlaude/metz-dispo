# app/services/firebird_delivery_items_import.rb
class FirebirdDeliveryItemsImport
  def self.import!
    new.import!
  end

  def import!
    Rails.logger.info "Starting Firebird import..."

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
        liefschnr = note["delivery_note_number"].to_s
        vauftragnr = note["sales_order_number"].to_s

        # Hole Auftragskopf-Daten aus WWS_VERKAUF1
        order_data = fetch_sales_order_from_firebird(vauftragnr)

        # Hole alle Positionen des Auftrags
        order_items = fetch_sales_order_items_from_firebird(vauftragnr)

        # Hole Lieferschein-Positionen
        items = fetch_delivery_items_from_firebird(liefschnr)

        items.each do |item|
          posnr = item["position"].to_i

          # Finde passende Auftragsposition
          order_item_data = order_items.find { |oi| oi["position"] == posnr } || {}

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
          Rails.logger.error "Fehler beim Import von #{liefschnr}-#{item['position']}: #{e.message}"
          result[:errors] << "#{liefschnr}-#{item['position']}: #{e.message}"
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
  # API Fetch Methoden
  # ============================================

  def fetch_delivery_notes_from_firebird
    response = FirebirdConnectApi.get("/delivery_notes")

    if response.success?
      parsed = JSON.parse(response.body)
      parsed["data"] || []
    else
      Rails.logger.error "Firebird API Fehler: #{response.code} - #{response.body}"
      []
    end
  end

  def fetch_delivery_items_from_firebird(liefschnr)
    response = FirebirdConnectApi.get("/delivery_notes/#{liefschnr}/items")

    if response.success?
      parsed = JSON.parse(response.body)
      parsed["data"] || []
    else
      Rails.logger.error "Firebird API Fehler für Items #{liefschnr}: #{response.code}"
      []
    end
  end

  def fetch_sales_order_from_firebird(vauftragnr)
    return {} if vauftragnr.blank? || vauftragnr == "0"

    response = FirebirdConnectApi.get("/sales_orders/#{vauftragnr}")

    if response.success?
      parsed = JSON.parse(response.body)
      parsed["data"] || {}
    else
      Rails.logger.warn "Auftrag #{vauftragnr} nicht gefunden: #{response.code}"
      {}
    end
  end

  def fetch_sales_order_items_from_firebird(vauftragnr)
    return [] if vauftragnr.blank? || vauftragnr == "0"

    response = FirebirdConnectApi.get("/sales_orders/#{vauftragnr}/items")

    if response.success?
      parsed = JSON.parse(response.body)
      parsed["data"] || []
    else
      Rails.logger.warn "Auftragspositionen für #{vauftragnr} nicht gefunden: #{response.code}"
      []
    end
  end

  # ============================================
  # Import Methoden
  # ============================================

  def import_item(item_data, note_data, order_data, order_item_data)
    liefschnr = item_data["delivery_note_number"].to_s
    posnr = item_data["position"].to_i

    if posnr <= 0
      Rails.logger.warn "⚠️  Überspringe Item mit ungültiger posnr: #{liefschnr}-#{posnr}"
      return :skipped
    end

    # 1. Versuche Delivery zu erstellen
    delivery = create_or_update_delivery(note_data, order_data)

    unless delivery
      Rails.logger.warn "⚠️  Überspringe Item #{liefschnr}-#{posnr} (Delivery konnte nicht erstellt werden)"
      return :skipped
    end

    # 2. UnassignedDeliveryItem mit allen Feldern
    unassigned_item = UnassignedDeliveryItem.find_or_initialize_by(
      liefschnr: liefschnr,
      posnr: posnr
    )

    was_new = unassigned_item.new_record?

    unassigned_item.assign_attributes(
      build_unassigned_item_attributes(item_data, note_data, order_data, order_item_data)
    )

    unassigned_item.save!

    # 3. DeliveryPosition
    create_or_update_delivery_position(item_data, note_data, order_item_data)

    was_new ? :imported : :updated
  end

  def build_unassigned_item_attributes(item_data, note_data, order_data, order_item_data)
    {
      # Primärschlüssel
      vauftragnr: note_data["sales_order_number"],

      # ============================================
      # Aus WWS_VERKAUF1 (order_data) - Auftragskopf
      # ============================================

      # Kundendaten
      kundennr: order_data["customer_number"] || note_data["customer_number"],
      kundname: order_data["customer_name"] || note_data["customer_name"],

      # Adressen
      kundadrnr: order_data["customer_address_number"],
      liefadrnr: order_data["delivery_address_number"] || note_data["delivery_address_number"],
      rechnadrnr: order_data["billing_address_number"] || note_data["billing_address_number"],
      ladeort: order_data["loading_location"],

      # Termine Auftrag
      datum: parse_date(order_data["date"]),
      geplliefdatum: parse_date(order_data["planned_delivery_date"] || note_data["planned_delivery_date"]),
      ladedatum: parse_date(order_data["loading_date"]),
      ladetermin: parse_date(order_data["loading_deadline"]),
      uhrzeit: order_data["time"],

      # Fahrzeug/Transport
      lkwnr: order_data["vehicle_number"] || note_data["vehicle_id"],
      fahrzeug: order_data["vehicle_type"],
      containernr: order_data["container_number"],
      transportart: order_data["transport_type"],
      spediteurnr: order_data["forwarder_number"],
      kfzkennzeichen1: order_data["license_plate_1"],
      kfzkennzeichen2: order_data["license_plate_2"],
      lieferart: order_data["delivery_type"],

      # Infotexte
      infoallgemein: order_data["info_general"],
      infoproduktion: order_data["info_production"],
      infoverladung: order_data["info_loading"],
      infoliefsch: order_data["info_delivery_note"],
      liefertext: order_data["delivery_text"],

      # Projekt/Bestellung
      objekt: order_data["project"],
      bestnrkd: order_data["customer_order_number"],
      besteller: order_data["orderer"],
      bestdatum: parse_date(order_data["order_date"]),

      # Bearbeiter
      bediener: order_data["operator"] || note_data["operator"],
      vertreter: order_data["sales_rep"] || note_data["sales_rep"],

      # ============================================
      # Aus WWS_VERKAUF2 (order_item_data) - Positionen
      # ============================================

      # Artikeldaten
      posart: order_item_data["position_type"] || item_data["position_type"],
      artikelnr: order_item_data["article_number"] || item_data["article_number"],
      artikelart: order_item_data["article_type"],
      bezeichn1: order_item_data["description_1"] || item_data["description_1"],
      bezeichn2: order_item_data["description_2"] || item_data["description_2"],
      langtext: order_item_data["long_text"],
      langliefer: order_item_data["long_delivery"],

      # Mengen
      menge: order_item_data["quantity"] || item_data["quantity"],
      bishliefmg: order_item_data["delivered_quantity"],
      einheit: order_item_data["unit"] || item_data["unit"],
      einhschl: order_item_data["unit_key"],
      preiseinh: order_item_data["price_unit"],

      # Gebinde
      gebindemg: order_item_data["container_quantity"],
      gebindschl: order_item_data["container_key"],
      gebindeinh: order_item_data["container_unit"],
      gebinhalt: order_item_data["container_content"],

      # Gewichte
      gewicht: order_item_data["weight"] || item_data["weight"],
      ladungsgewicht: order_item_data["loading_weight"],

      # Paletten
      palanzahl: order_item_data["pallet_count"],
      palettennr: order_item_data["pallet_number"],

      # Preise Original
      listpreis: order_item_data["list_price"],
      einhpreis: order_item_data["unit_price"] || item_data["unit_price"],
      netto: order_item_data["net_amount"] || item_data["net_amount"],
      mwst: order_item_data["vat"] || item_data["vat"],
      brutto: order_item_data["gross_amount"] || item_data["gross_amount"],
      rabatt: order_item_data["discount"] || item_data["discount"],
      rabattart: order_item_data["discount_type"],
      steuerschl: order_item_data["tax_key"],
      mwstsatz: order_item_data["vat_rate"],

      # Lager/Charge
      lager: order_item_data["warehouse"],
      lagerfach: order_item_data["storage_bin"],
      chargennr: order_item_data["batch_number"],
      seriennr: order_item_data["serial_number"],

      # ============================================
      # Planungsfelder (Defaults für neue Items)
      # ============================================
      planned_date: parse_date(order_data["planned_delivery_date"] || note_data["planned_delivery_date"]),
      planned_time: parse_time(order_data["time"]),
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
    kundennr = note_data["customer_number"]

    # Erstelle Kunde falls er nicht existiert
    ensure_customer_exists(kundennr, note_data["customer_name"])

    delivery = Delivery.find_or_initialize_by(
      liefschnr: note_data["delivery_note_number"].to_s
    )

    delivery.assign_attributes(
      kundennr: kundennr,
      kundname: note_data["customer_name"],
      datum: parse_date(note_data["date"]),
      ladedatum: parse_datetime(note_data["planned_delivery_date"]),
      geplliefdatum: parse_date(note_data["planned_delivery_date"]),
      vauftragnr: note_data["sales_order_number"]&.to_s || "0",
      liefadrnr: note_data["delivery_address_number"],
      rechnadrnr: note_data["billing_address_number"],
      kundadrnr: note_data["billing_address_number"],
      gedruckt: false,
      selbstabholung: false,
      gutschrift: false,
      fruehbezug: false
    )

    delivery.save!
    Rails.logger.info "✓ Delivery erstellt/aktualisiert: #{delivery.liefschnr}"
    delivery
  rescue => e
    Rails.logger.error "✗ Fehler beim Erstellen von Delivery #{note_data['delivery_note_number']}: #{e.message}"
    Rails.logger.error e.backtrace.first(3).join("\n")
    nil
  end

  def ensure_customer_exists(kundennr, kundname)
    return if Customer.exists?(kundennr: kundennr)

    Rails.logger.info "→ Erstelle fehlenden Kunde #{kundennr}: #{kundname}"

    customer = Customer.new(
      kundennr: kundennr,
      kundgruppe: 1,
      bundesland: "BY",
      rabatt: 0.0,
      zahlungart: "BAR",
      umsatzsteuer: "N",
      gekuendigt: false,
      mitgliednr: nil
    )

    customer.skip_validations = true
    customer.save!

    Rails.logger.info "✓ Kunde #{kundennr} erstellt"
  rescue => e
    Rails.logger.error "✗ Fehler beim Erstellen von Kunde #{kundennr}: #{e.message}"
    Rails.logger.error e.backtrace.first(5).join("\n")
    raise
  end

  def create_or_update_delivery_position(item_data, note_data, order_item_data)
    position = DeliveryPosition.find_or_initialize_by(
      liefschnr: item_data["delivery_note_number"].to_s,
      posnr: item_data["position"].to_i
    )

    was_new = position.new_record?

    position.assign_attributes(
      artikelnr: item_data["article_number"] || "UNKNOWN",
      bezeichn1: item_data["description_1"] || "Aus Firebird importiert",
      bezeichn2: item_data["description_2"] || order_item_data["description_2"],
      liefmenge: item_data["quantity"] || 0,
      einheit: item_data["unit"] || "ST",
      gewicht: order_item_data["weight"],
      ladungsgewicht: order_item_data["loading_weight"],
      tour_id: nil,
      sequence_number: nil
    )

    position.save!

    if was_new
      Rails.logger.info "✓ DeliveryPosition erstellt: #{position.position_id}"
    else
      Rails.logger.info "✓ DeliveryPosition aktualisiert: #{position.position_id}"
    end
  rescue => e
    Rails.logger.error "✗ Fehler beim Erstellen von DeliveryPosition #{item_data['delivery_note_number']}-#{item_data['position']}: #{e.message}"
    raise
  end

  def cleanup_obsolete_items(current_delivery_notes)
    current_liefschnrs = current_delivery_notes.map { |note| note["delivery_note_number"].to_s }

    obsolete_items = UnassignedDeliveryItem
                       .where(status: [ "draft", "ready" ])
                       .where(tabelle_herkunft: "firebird_import")
                       .where.not(liefschnr: current_liefschnrs)

    obsolete_count = obsolete_items.count

    if obsolete_count > 0
      Rails.logger.info "Cleanup: #{obsolete_count} obsolete Items gefunden"
      obsolete_items.destroy_all
    end
  end

  # ============================================
  # Helper Methoden
  # ============================================

  def parse_datetime(value)
    return nil if value.blank?
    Time.zone.parse(value.to_s)
  rescue
    nil
  end

  def parse_date(value)
    return nil if value.blank?
    datetime = parse_datetime(value)
    datetime&.to_date
  end

  def parse_time(value)
    return nil if value.blank?
    # Wenn es schon ein Zeit-String ist (z.B. "14:30")
    if value.is_a?(String) && value.match?(/^\d{1,2}:\d{2}/)
      value
    else
      datetime = parse_datetime(value)
      datetime&.strftime("%H:%M")
    end
  end
end
