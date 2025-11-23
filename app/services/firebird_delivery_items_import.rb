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
        items = fetch_delivery_items_from_firebird(liefschnr)

        items.each do |item|
          import_result = import_item(item, note)

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

  # app/services/firebird_delivery_items_import.rb

  def import_item(item_data, note_data)
    liefschnr = item_data["delivery_note_number"].to_s
    posnr = item_data["position"].to_i

    if posnr <= 0
      Rails.logger.warn "⚠️  Überspringe Item mit ungültiger posnr: #{liefschnr}-#{posnr}"
      return :skipped
    end

    # 1. Versuche Delivery zu erstellen
    delivery = create_or_update_delivery(note_data)

    unless delivery
      Rails.logger.warn "⚠️  Überspringe Item #{liefschnr}-#{posnr} (Delivery konnte nicht erstellt werden)"
      return :skipped
    end

    # 2. UnassignedDeliveryItem
    unassigned_item = UnassignedDeliveryItem.find_or_initialize_by(
      liefschnr: liefschnr,
      posnr: posnr
    )

    was_new = unassigned_item.new_record?

    unassigned_item.assign_attributes(
      artikel_nr: item_data["article_number"],
      bezeichnung: item_data["description_1"],
      menge: item_data["quantity"],
      einheit: item_data["unit"],
      kund_adr_nr: note_data["customer_number"],
      werk_adr_nr: note_data["delivery_address_number"],
      beginn: parse_datetime(note_data["planned_delivery_date"]),
      planned_date: parse_date(note_data["planned_delivery_date"]),
      planned_time: parse_time(note_data["planned_delivery_date"]),
      status: unassigned_item.status || "ready",
      tabelle_herkunft: "firebird_import",
      gedruckt: 0,
      plan_nr: 0,
      kontrakt_nr: "0",
      invoiced: false,
      typ: 0,
      freight_price: 0.0,
      loading_price: 0.0,
      unloading_price: 0.0
    )

    unassigned_item.save!

    # 3. DeliveryPosition - WICHTIG!
    create_or_update_delivery_position(item_data, note_data)

    was_new ? :imported : :updated
  end

  def create_or_update_delivery(note_data)
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

    customer.skip_validations = true  # Setze Flag für Import
    customer.save!

    Rails.logger.info "✓ Kunde #{kundennr} erstellt"
  rescue => e
    Rails.logger.error "✗ Fehler beim Erstellen von Kunde #{kundennr}: #{e.message}"
    Rails.logger.error e.backtrace.first(5).join("\n")
    raise
  end

  def create_or_update_delivery_position(item_data, note_data)
    position = DeliveryPosition.find_or_initialize_by(
      liefschnr: item_data["delivery_note_number"].to_s,
      posnr: item_data["position"].to_i
    )

    was_new = position.new_record?

    position.assign_attributes(
      artikelnr: item_data["article_number"] || "UNKNOWN",
      bezeichn1: item_data["description_1"] || "Aus Firebird importiert",
      bezeichn2: item_data["description_2"],
      liefmenge: item_data["quantity"] || 0,
      einheit: item_data["unit"] || "ST",
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
    datetime = parse_datetime(value)
    datetime&.strftime("%H:%M") if datetime
  end
end
