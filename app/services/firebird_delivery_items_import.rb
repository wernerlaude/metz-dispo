# app/services/firebird_delivery_items_import.rb
require "net/http"
require "json"

class FirebirdDeliveryItemsImport
  FIREBIRD_API_BASE = "http://192.168.33.61:8080/api/v1"

  def self.import!
    new.import!
  end

  def initialize
    @imported_count = 0
    @updated_count = 0
    @skipped_count = 0
    @errors = []
  end

  def import!
    puts "Starting Firebird import..."

    delivery_notes = fetch_delivery_notes

    if delivery_notes.nil?
      puts "Fehler beim Abrufen der Lieferscheine"
      return { success: false, error: "API nicht erreichbar" }
    end

    puts "#{delivery_notes.count} Lieferscheine gefunden"

    delivery_notes.each do |delivery_note|
      import_delivery_note(delivery_note)
    end

    cleanup_obsolete_items

    result = {
      success: true,
      imported: @imported_count,
      updated: @updated_count,
      skipped: @skipped_count,
      errors: @errors
    }

    puts "Import abgeschlossen: #{@imported_count} neu, #{@updated_count} aktualisiert, #{@skipped_count} uebersprungen"
    result
  end

  private

  def fetch_delivery_notes
    url = "#{FIREBIRD_API_BASE}/delivery_notes?lkwnr_min=1&lkwnr_max=8&auftstatus=2"

    begin
      uri = URI(url)
      response = Net::HTTP.get_response(uri)

      if response.code == "200"
        data = JSON.parse(response.body)
        data["data"] || []
      else
        puts "API Error: #{response.code}"
        nil
      end
    rescue => e
      puts "Fehler beim API-Aufruf: #{e.message}"
      nil
    end
  end

  def fetch_items(liefschnr)
    url = "#{FIREBIRD_API_BASE}/delivery_notes/#{liefschnr}/items"

    begin
      uri = URI(url)
      response = Net::HTTP.get_response(uri)

      if response.code == "200"
        data = JSON.parse(response.body)
        data["data"] || []
      else
        puts "API Error fuer Items #{liefschnr}: #{response.code}"
        []
      end
    rescue => e
      puts "Fehler beim Abrufen von Items #{liefschnr}: #{e.message}"
      []
    end
  end

  def import_delivery_note(delivery_note)
    liefschnr = delivery_note["delivery_note_number"]

    items = fetch_items(liefschnr)

    if items.empty?
      puts "Keine Items fuer Lieferschein #{liefschnr}"
      return
    end

    items.each do |item|
      import_item(delivery_note, item)
    end
  end

  def import_item(delivery_note, item)
    liefschnr = item["delivery_note_number"]
    posnr = item["position"]

    existing = UnassignedDeliveryItem.find_by(
      liefschnr: liefschnr,
      posnr: posnr
    )

    if existing
      if update_item(existing, delivery_note, item)
        @updated_count += 1
      else
        @skipped_count += 1
      end
    else
      if create_item(delivery_note, item)
        @imported_count += 1
      end
    end
  rescue => e
    @errors << "#{liefschnr}-#{posnr}: #{e.message}"
    puts "Fehler beim Import von #{liefschnr}-#{posnr}: #{e.message}"
  end

  def create_item(delivery_note, item)
    UnassignedDeliveryItem.create!(
      liefschnr: item["delivery_note_number"].to_s,
      posnr: item["position"],
      vauftragnr: item["sales_order_number"],
      kund_adr_nr: delivery_note["customer_number"],
      werk_adr_nr: delivery_note["delivery_address_number"],
      artikel_nr: item["article_number"],
      bezeichnung: [item["description_1"], item["description_2"]].compact.join(" ").strip,
      menge: item["quantity"],
      einheit: item["unit"],
      typ: determine_type(item["unit"]),
      brutto: item["gross_amount"],
      beginn: parse_datetime(delivery_note["date"]),
      planned_date: parse_date(delivery_note["planned_delivery_date"]),
      status: "draft",
      gedruckt: 0,
      plan_nr: 0,
      kontrakt_nr: "0",
      tabelle_herkunft: "firebird_import"
    )
    true
  rescue => e
    puts "Fehler beim Erstellen: #{e.message}"
    false
  end

  def update_item(existing_item, delivery_note, item)
    updates = {}
    updates[:menge] = item["quantity"] if item["quantity"] && existing_item.menge != item["quantity"]
    updates[:planned_date] = parse_date(delivery_note["planned_delivery_date"]) if delivery_note["planned_delivery_date"]
    updates[:beginn] = parse_datetime(delivery_note["date"]) if delivery_note["date"]

    bezeichnung = [item["description_1"], item["description_2"]].compact.join(" ").strip
    updates[:bezeichnung] = bezeichnung if existing_item.bezeichnung.blank? && bezeichnung.present?

    if updates.any?
      existing_item.update!(updates)
      true
    else
      false
    end
  end

  def cleanup_obsolete_items
    UnassignedDeliveryItem
      .where(status: ["draft", "ready"])
      .where(tabelle_herkunft: "firebird_import")
      .find_each do |item|
      delivery_notes = fetch_delivery_notes
      exists = delivery_notes.any? { |dn| dn["delivery_note_number"].to_s == item.liefschnr.to_s }

      unless exists
        item.destroy
        puts "Obsoletes Item entfernt: #{item.liefschnr}-#{item.posnr}"
      end
    end
  end

  def determine_type(einheit)
    case einheit&.upcase
    when "T", "TO", "KG", "CBM", "M³"
      1
    when "SACK", "STK"
      0
    else
      0
    end
  end

  def parse_date(date_string)
    return nil if date_string.blank?
    Date.parse(date_string) rescue nil
  end

  def parse_datetime(datetime_string)
    return nil if datetime_string.blank?
    DateTime.parse(datetime_string) rescue nil
  end
end