# app/services/firebird_write_back_service.rb
require "net/http"
require "json"

class FirebirdWriteBackService
  FIREBIRD_API_BASE = "http://192.168.33.61:8080/api/v1"

  # Update Item Menge
  def self.update_item_quantity(liefschnr, posnr, new_quantity)
    new.update_item_quantity(liefschnr, posnr, new_quantity)
  end

  # Update Delivery Note LKW
  def self.update_delivery_note_truck(liefschnr, lkwnr)
    new.update_delivery_note_truck(liefschnr, lkwnr)
  end

  # Update Delivery Note Datum
  def self.update_delivery_note_date(liefschnr, date)
    new.update_delivery_note_date(liefschnr, date)
  end

  def update_item_quantity(liefschnr, posnr, new_quantity)
    url = "#{FIREBIRD_API_BASE}/delivery_notes/#{liefschnr}/items/#{posnr}"

    payload = {
      item: {
        liefmenge: new_quantity
      }
    }

    response = make_patch_request(url, payload)

    if response[:success]
      puts "Item #{liefschnr}-#{posnr} Menge aktualisiert: #{new_quantity}"
      { success: true, data: response[:data] }
    else
      puts "Fehler: #{response[:error]}"
      { success: false, error: response[:error] }
    end
  end

  def update_delivery_note_truck(liefschnr, lkwnr)
    url = "#{FIREBIRD_API_BASE}/delivery_notes/#{liefschnr}"

    payload = {
      delivery_note: {
        lkwnr: lkwnr
      }
    }

    response = make_patch_request(url, payload)

    if response[:success]
      puts "Lieferschein #{liefschnr} LKW aktualisiert: #{lkwnr}"
      { success: true, data: response[:data] }
    else
      puts "Fehler: #{response[:error]}"
      { success: false, error: response[:error] }
    end
  end

  def update_delivery_note_date(liefschnr, date)
    url = "#{FIREBIRD_API_BASE}/delivery_notes/#{liefschnr}"

    formatted_date = date.is_a?(String) ? date : date.strftime("%Y-%m-%d")

    payload = {
      delivery_note: {
        geplliefdatum: formatted_date
      }
    }

    response = make_patch_request(url, payload)

    if response[:success]
      puts "Lieferschein #{liefschnr} Datum aktualisiert"
      { success: true, data: response[:data] }
    else
      puts "Fehler: #{response[:error]}"
      { success: false, error: response[:error] }
    end
  end

  private

  def make_patch_request(url, payload)
    begin
      uri = URI(url)
      http = Net::HTTP.new(uri.host, uri.port)

      request = Net::HTTP::Patch.new(uri.path)
      request["Content-Type"] = "application/json"
      request.body = payload.to_json

      response = http.request(request)

      if response.code == "200"
        data = JSON.parse(response.body)
        { success: true, data: data["data"] }
      else
        error_data = JSON.parse(response.body) rescue {}
        { success: false, error: error_data["error"] || "HTTP #{response.code}" }
      end
    rescue => e
      { success: false, error: e.message }
    end
  end
end
