# app/services/firebird_write_back_service.rb
class FirebirdWriteBackService
  def initialize
    @use_direct_connection = Rails.env.production?

    if @use_direct_connection
      @connection = Firebird::Connection.instance
    end
  end

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

  # Update Sales Order LKW (WWS_VERKAUF1)
  def self.update_sales_order_truck(vauftragnr, lkwnr)
    new.update_sales_order_truck(vauftragnr, lkwnr)
  end

  # Update Sales Order Status (WWS_VERKAUF1) - für Disponierung
  def self.update_order_status(vauftragnr, status)
    new.update_order_status(vauftragnr, status)
  end

  # Markiere Auftrag als disponiert (AUFTSTATUS = 3)
  def self.mark_as_dispatched(vauftragnr)
    new.update_order_status(vauftragnr, 3)
  end

  def update_item_quantity(liefschnr, posnr, new_quantity)
    if @use_direct_connection
      update_item_quantity_direct(liefschnr, posnr, new_quantity)
    else
      update_item_quantity_api(liefschnr, posnr, new_quantity)
    end
  end

  def update_delivery_note_truck(liefschnr, lkwnr)
    if @use_direct_connection
      update_delivery_note_truck_direct(liefschnr, lkwnr)
    else
      update_delivery_note_truck_api(liefschnr, lkwnr)
    end
  end

  def update_delivery_note_date(liefschnr, date)
    if @use_direct_connection
      update_delivery_note_date_direct(liefschnr, date)
    else
      update_delivery_note_date_api(liefschnr, date)
    end
  end

  def update_sales_order_truck(vauftragnr, lkwnr)
    if @use_direct_connection
      update_sales_order_truck_direct(vauftragnr, lkwnr)
    else
      # API hat diese Methode nicht, also direkt oder skip
      Rails.logger.warn "update_sales_order_truck nicht verfügbar über API"
      { success: false, error: "Nicht verfügbar in Development" }
    end
  end

  def update_order_status(vauftragnr, status)
    if @use_direct_connection
      update_order_status_direct(vauftragnr, status)
    else
      Rails.logger.warn "update_order_status nicht verfügbar über API"
      { success: false, error: "Nicht verfügbar in Development" }
    end
  end

  private

  # ============================================
  # PRODUCTION: Direkte Firebird-Verbindung
  # ============================================

  def update_item_quantity_direct(liefschnr, posnr, new_quantity)
    sql = "UPDATE WWS_VLIEFER2 SET LIEFMENGE = #{new_quantity.to_f} WHERE LIEFSCHNR = '#{escape_sql(liefschnr)}' AND POSNR = #{posnr.to_i}"

    begin
      @connection.execute_update(sql)
      Rails.logger.info "✓ Item #{liefschnr}-#{posnr} Menge aktualisiert: #{new_quantity}"
      { success: true }
    rescue => e
      Rails.logger.error "✗ Fehler beim Update von Item #{liefschnr}-#{posnr}: #{e.message}"
      { success: false, error: e.message }
    end
  end

  def update_delivery_note_truck_direct(liefschnr, lkwnr)
    sql = "UPDATE WWS_VLIEFER1 SET LKWNR = #{lkwnr.to_i} WHERE LIEFSCHNR = '#{escape_sql(liefschnr)}'"

    begin
      @connection.execute_update(sql)
      Rails.logger.info "✓ Lieferschein #{liefschnr} LKW aktualisiert: #{lkwnr}"
      { success: true }
    rescue => e
      Rails.logger.error "✗ Fehler beim Update von Lieferschein #{liefschnr}: #{e.message}"
      { success: false, error: e.message }
    end
  end

  def update_delivery_note_date_direct(liefschnr, date)
    formatted_date = date.is_a?(String) ? date : date.strftime("%Y-%m-%d")
    sql = "UPDATE WWS_VLIEFER1 SET GEPLLIEFDATUM = '#{formatted_date}' WHERE LIEFSCHNR = '#{escape_sql(liefschnr)}'"

    begin
      @connection.execute_update(sql)
      Rails.logger.info "✓ Lieferschein #{liefschnr} Datum aktualisiert: #{formatted_date}"
      { success: true }
    rescue => e
      Rails.logger.error "✗ Fehler beim Update von Lieferschein #{liefschnr}: #{e.message}"
      { success: false, error: e.message }
    end
  end

  def update_sales_order_truck_direct(vauftragnr, lkwnr)
    sql = "UPDATE WWS_VERKAUF1 SET LKWNR = #{lkwnr.to_i} WHERE VAUFTRAGNR = '#{escape_sql(vauftragnr)}'"

    begin
      @connection.execute_update(sql)
      Rails.logger.info "✓ Auftrag #{vauftragnr} LKW aktualisiert: #{lkwnr}"
      { success: true }
    rescue => e
      Rails.logger.error "✗ Fehler beim Update von Auftrag #{vauftragnr}: #{e.message}"
      { success: false, error: e.message }
    end
  end

  def update_order_status_direct(vauftragnr, status)
    sql = "UPDATE WWS_VERKAUF1 SET AUFTSTATUS = #{status.to_i} WHERE VAUFTRAGNR = '#{escape_sql(vauftragnr)}'"

    begin
      @connection.execute_update(sql)
      Rails.logger.info "✓ Auftrag #{vauftragnr} Status aktualisiert: #{status}"
      { success: true }
    rescue => e
      Rails.logger.error "✗ Fehler beim Status-Update von Auftrag #{vauftragnr}: #{e.message}"
      { success: false, error: e.message }
    end
  end

  # ============================================
  # DEVELOPMENT: HTTP API Verbindung
  # ============================================

  FIREBIRD_API_BASE = ENV.fetch("FIREBIRD_API_URL", "http://192.168.33.61:8080/api/v1")

  def update_item_quantity_api(liefschnr, posnr, new_quantity)
    url = "#{FIREBIRD_API_BASE}/delivery_notes/#{liefschnr}/items/#{posnr}"
    payload = { item: { liefmenge: new_quantity } }

    response = make_patch_request(url, payload)

    if response[:success]
      Rails.logger.info "✓ Item #{liefschnr}-#{posnr} Menge aktualisiert: #{new_quantity}"
      { success: true, data: response[:data] }
    else
      Rails.logger.error "✗ Fehler: #{response[:error]}"
      { success: false, error: response[:error] }
    end
  end

  def update_delivery_note_truck_api(liefschnr, lkwnr)
    url = "#{FIREBIRD_API_BASE}/delivery_notes/#{liefschnr}"
    payload = { delivery_note: { lkwnr: lkwnr } }

    response = make_patch_request(url, payload)

    if response[:success]
      Rails.logger.info "✓ Lieferschein #{liefschnr} LKW aktualisiert: #{lkwnr}"
      { success: true, data: response[:data] }
    else
      Rails.logger.error "✗ Fehler: #{response[:error]}"
      { success: false, error: response[:error] }
    end
  end

  def update_delivery_note_date_api(liefschnr, date)
    url = "#{FIREBIRD_API_BASE}/delivery_notes/#{liefschnr}"
    formatted_date = date.is_a?(String) ? date : date.strftime("%Y-%m-%d")
    payload = { delivery_note: { geplliefdatum: formatted_date } }

    response = make_patch_request(url, payload)

    if response[:success]
      Rails.logger.info "✓ Lieferschein #{liefschnr} Datum aktualisiert"
      { success: true, data: response[:data] }
    else
      Rails.logger.error "✗ Fehler: #{response[:error]}"
      { success: false, error: response[:error] }
    end
  end

  def make_patch_request(url, payload)
    require "net/http"
    require "json"

    begin
      uri = URI(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.read_timeout = 30

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

  def escape_sql(value)
    value.to_s.gsub("'", "''")
  end
end
