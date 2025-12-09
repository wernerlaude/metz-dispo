# app/controllers/tours_controller.rb
class ToursController < ApplicationController
  before_action :set_tour, only: [ :show, :update, :destroy, :details, :update_sequence, :toggle_completed, :toggle_sent ]

  def index
    @tours = load_tours
    @unassigned_deliveries = load_unassigned_delivery_items
  end

  def show
    @positions = @tour.delivery_items.order(:sequence_number, :liefschnr, :posnr)
    @deliveries_data = @positions.map { |item| build_delivery_data(item) }
  end

  def update
    if @tour.update(tour_params)
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace(@tour, partial: "tours/tour_card", locals: { tour: @tour }) }
        format.json { render json: { success: true, tour: @tour } }
        format.html { redirect_to request.referer || tours_path, notice: "Tour aktualisiert" }
      end
    else
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace(@tour, partial: "tours/tour_card", locals: { tour: @tour }) }
        format.json { render json: { success: false, errors: @tour.errors.full_messages }, status: :unprocessable_entity }
        format.html { render :edit, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    if @tour.delivery_items.any?
      respond_to do |format|
        format.json { render json: { success: false, message: "Tour kann nicht gelöscht werden - enthält noch Positionen" }, status: :unprocessable_entity }
        format.html do
          flash[:alert] = "Tour kann nicht gelöscht werden - enthält noch Positionen"
          redirect_back_or_to tours_path
        end
      end
    else
      @tour.destroy
      respond_to do |format|
        format.json { render json: { success: true, message: "Tour gelöscht" } }
        format.html do
          flash[:notice] = "Tour wurde gelöscht"
          redirect_back_or_to tours_path
        end
      end
    end
  end

  def completed
    @tours = Tour.includes(:driver, :vehicle, :trailer, :loading_location)
                 .filter_by(filter_params)
                 .order(tour_date: :desc)

    @drivers = Driver.active.order(:first_name, :last_name)
    @vehicles = Vehicle.order(:license_plate)
    @trailers = Trailer.order(:license_plate)
    @loading_locations = LoadingLocation.active.order(:werk_name)
  end

  def toggle_completed
    @tour.update(completed: !@tour.completed)
    render json: { success: true, completed: @tour.completed }
  end

  def toggle_sent
    @tour.update(sent: !@tour.sent)
    render json: { success: true, sent: @tour.sent }
  end

  def refresh_unassigned
    # Lieferungen importieren
    delivery_result = FirebirdDeliveryItemsImport.import!

    # Abholungen importieren
    pickup_result = FirebirdPurchaseOrdersImport.import!

    total_imported = delivery_result[:imported] + pickup_result[:imported]
    total_updated = delivery_result[:updated] + pickup_result[:updated]
    total_skipped = delivery_result[:skipped] + pickup_result[:skipped]

    redirect_to root_path,
                notice: "#{total_imported} neue Positionen importiert, #{total_updated} aktualisiert, #{total_skipped} übersprungen"
  end

  # PATCH /delivery_positions/:id/unassign
  def unassign_delivery_position
    position_id = params[:id]
    parts = position_id.to_s.split("-")

    if parts.length >= 2
      liefschnr = parts[0]
      posnr = parts[1].to_i
      item = UnassignedDeliveryItem.find_by!(liefschnr: liefschnr, posnr: posnr)

      item.unassign!

      respond_to do |format|
        format.html { redirect_back fallback_location: tours_path, notice: "Position aus Tour entfernt" }
        format.turbo_stream { render turbo_stream: turbo_stream.remove("position_#{position_id}") }
        format.json { render json: { success: true } }
      end
    end
  rescue ActiveRecord::RecordNotFound
    respond_to do |format|
      format.html { redirect_back fallback_location: tours_path, alert: "Position nicht gefunden" }
      format.json { render json: { error: "Position nicht gefunden" }, status: :not_found }
    end
  end

  def create
    @tour = Tour.create!(
      name: generate_tour_name,
      tour_date: Date.current
    )

    position_ids = params[:position_ids]&.split(",") || []
    assigned_count = assign_positions_to_tour(@tour, position_ids) if position_ids.any?

    respond_to do |format|
      format.json do
        render json: {
          success: true,
          message: "Neue Tour '#{@tour.name}' erstellt mit #{assigned_count} Positionen"
        }
      end
      format.html do
        redirect_to tours_path
      end
    end
  end

  def assign_positions
    position_ids = params[:position_ids] || []

    assigned_count = assign_positions_to_tour(@tour, position_ids)

    respond_to do |format|
      format.json do
        render json: {
          success: true,
          message: "#{assigned_count} Position(en) zur Tour hinzugefügt"
        }
      end
    end
  rescue => e
    render json: {
      success: false,
      message: "Fehler beim Zuweisen: #{e.message}"
    }, status: :unprocessable_entity
  end

  # app/controllers/tours_controller.rb

  # PDF für Büro (mit Preis)
  def export_pdf
    @tour = Tour.find(params[:id])
    @positions = @tour.delivery_items.order("sequence_number ASC NULLS LAST, liefschnr, posnr")
    deliveries_data = @positions.map { |item| build_delivery_data(item) }

    pdf = TourPdf.new(@tour, @positions, deliveries_data: deliveries_data, show_price: true)

    send_data pdf.render,
              filename: "Tourenplan_#{@tour.name.to_s.gsub(/[^0-9A-Za-z.\-]/, '_')}_Buero.pdf",
              type: "application/pdf",
              disposition: "inline"
  end

  # NEU: Für Fahrer (ohne Preis)
  def export_pdf_driver
    @tour = Tour.find(params[:id])
    @positions = @tour.delivery_items.order("sequence_number ASC NULLS LAST, liefschnr, posnr")
    deliveries_data = @positions.map { |item| build_delivery_data(item) }

    pdf = TourPdf.new(@tour, @positions, deliveries_data: deliveries_data, show_price: false)

    send_data pdf.render,
              filename: "Tourenplan_#{@tour.name.to_s.gsub(/[^0-9A-Za-z.\-]/, '_')}_Fahrer.pdf",
              type: "application/pdf",
              disposition: "inline"
  end

  def details
    positions = load_tour_positions

    render json: {
      id: @tour.id,
      name: @tour.name || "Tour #{@tour.id}",
      date: @tour.tour_date&.strftime("%d.%m.%Y"),
      total_weight: @tour.total_weight,
      driver: build_driver_data,
      vehicle: build_vehicle_data,
      trailer: build_trailer_data,
      loading_location: build_loading_location_data,
      loading_locations: LoadingLocation.active.order(:werk_name).map { |loc| { id: loc.id, name: loc.werk_name } },
      deliveries: positions.map { |item| build_delivery_data(item) }
    }
  rescue => e
    Rails.logger.error "Tour details error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    render json: { error: "Fehler beim Laden der Tour-Daten: #{e.message}" }, status: :unprocessable_entity
  end

  def update_sequence
    positions_params = params.require(:positions)

    validate_positions_params(positions_params)
    update_position_sequences(positions_params)

    render json: {
      success: true,
      message: "Tour-Reihenfolge erfolgreich aktualisiert",
      updated_at: Time.current,
      positions_updated: positions_params.length
    }
  rescue ActionController::ParameterMissing => e
    render json: { error: "Parameter fehlen", details: e.message }, status: :bad_request
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: "Fehler beim Speichern der Reihenfolge", details: e.message }, status: :unprocessable_entity
  rescue => e
    Rails.logger.error "Update sequence error: #{e.message}"
    render json: { error: "Unerwarteter Fehler beim Speichern", details: e.message }, status: :internal_server_error
  end

  private

  def set_tour
    @tour = Tour.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    respond_to do |format|
      format.json { render json: { error: "Tour nicht gefunden" }, status: :not_found }
      format.html { redirect_to tours_path, alert: "Tour nicht gefunden" }
    end
  end

  def filter_params
    params.permit(:name, :tour_date, :driver_id, :vehicle_id, :trailer_id, :completed)
  end

  def tour_params
    params.require(:tour).permit(
      :name, :tour_date, :vehicle_id, :trailer_id, :driver_id,
      :loading_location_id, :notes, :departure_time, :departure_at,
      :arrival_at, :km_start, :km_end, :fuel_start, :fuel_end,
      :carrier, :sent, :completed, :delivery_type, :tour_type
    )
  end

  def load_tours
    Tour.includes(:driver, :loading_location, :delivery_items)
        .where(completed: false)
        .order(created_at: :desc)
  end

  def load_tour_positions
    @tour.delivery_items.order(:sequence_number, :liefschnr, :posnr)
  end

  def build_driver_data
    {
      id: @tour.driver_id,
      name: @tour.driver&.full_name || (@tour.driver_id ? "Fahrer #{@tour.driver_id}" : "Kein Fahrer")
    }
  end

  def build_vehicle_data
    # Erst direktes Fahrzeug der Tour, dann aus Positionen
    if @tour.vehicle.present?
      {
        id: @tour.vehicle_id,
        name: @tour.vehicle.display_name
      }
    elsif @tour.effective_vehicle.present?
      {
        id: @tour.effective_vehicle.id,
        name: @tour.effective_vehicle.display_name
      }
    else
      # Fallback: Fahrzeugtyp aus erster Position
      first_lkwnr = @tour.delivery_items.where.not(lkwnr: [ nil, "" ]).pick(:lkwnr)
      if first_lkwnr.present?
        type_label = Vehicle.type_label_for_number(first_lkwnr)
        { name: type_label || "LKW #{first_lkwnr}" }
      else
        { name: "Kein Fahrzeug" }
      end
    end
  end

  def build_loading_location_data
    # Erst direkter Ladeort der Tour
    if @tour.loading_location.present?
      {
        id: @tour.loading_location_id,
        name: @tour.loading_location.werk_name
      }
    else
      # Fallback: Ladeort aus erster Position
      first_ladeort = @tour.delivery_items.where.not(ladeort: [ nil, "" ]).pick(:ladeort)
      if first_ladeort.present?
        # Versuche LoadingLocation zu finden
        location = LoadingLocation.where("LOWER(werk_name) LIKE LOWER(?)", "%#{first_ladeort}%").first
        if location
          { id: location.id, name: location.werk_name }
        else
          { name: first_ladeort }
        end
      else
        { name: "Kein Ladeort" }
      end
    end
  end

  def build_trailer_data
    if @tour.trailer.present?
      {
        id: @tour.trailer_id,
        name: @tour.trailer.license_plate
      }
    else
      { name: "Kein Hänger" }
    end
  end

  def build_delivery_data(item)
    delivery_address = find_delivery_address(item)

    {
      id: item.position_id,
      delivery_id: item.liefschnr,
      sequence_number: item.sequence_number || 1,
      planned_time: item.uhrzeit,
      customer_name: delivery_address&.dig(:name1) || item.kundname,
      positions: [ build_position_data(item) ],
      delivery_address: build_address_data(delivery_address, item),
      kessel: item.kessel,
      weight: item.calculated_weight,
      selbstabholung: item.delivery&.selbstabholung,
      fruehbezug: item.delivery&.fruehbezug,
      gutschrift: item.delivery&.gutschrift,
      liefschnr: item.liefschnr
    }
  end

  # ============================================
  # Adress-Loading: API oder Direkt
  # ============================================

  def find_delivery_address(item)
    address_nr = item.liefadrnr || item.kundadrnr
    return nil unless address_nr.present?

    # Versuche zuerst direkte Firebird-Verbindung (Production)
    if use_direct_firebird_connection?
      address = find_address_from_firebird(address_nr)
      return address if address
    end

    # Fallback: HTTP API (Development)
    if defined?(FirebirdConnectApi)
      address = find_address_from_api(address_nr)
      return address if address
    end

    # Letzter Fallback
    {
      name1: item.kundname,
      name2: nil,
      strasse: "Lieferadresse #{address_nr}",
      plz: "",
      ort: ""
    }
  end

  def use_direct_firebird_connection?
    defined?(Firebird::Connection) && Firebird::Connection.instance.present?
  rescue
    false
  end

  def find_address_from_firebird(address_nr)
    return nil unless defined?(Firebird::Connection)

    connection = Firebird::Connection.instance
    rows = connection.query("SELECT * FROM ADRESSEN WHERE NUMMER = #{address_nr.to_i}")

    unless rows.empty?
      row = rows.first
      return {
        name1: row["NAME1"]&.to_s&.strip,
        name2: row["NAME2"]&.to_s&.strip,
        strasse: row["STRASSE"]&.to_s&.strip,
        plz: row["PLZ"]&.to_s&.strip,
        ort: row["ORT"]&.to_s&.strip,
        telefon1: row["TELEFON1"]&.to_s&.strip,
        telefon2: row["TELEFON2"]&.to_s&.strip,
        telefax: row["TELEFAX"]&.to_s&.strip
      }
    end

    nil
  rescue => e
    Rails.logger.warn "Firebird Adresse #{address_nr} nicht verfügbar: #{e.message}"
    nil
  end

  def find_address_from_api(address_nr)
    response = FirebirdConnectApi.get("/addresses/#{address_nr}")

    if response.success?
      parsed = JSON.parse(response.body)
      data = parsed["data"]

      if data
        return {
          name1: data["name_1"],
          name2: data["name_2"],
          strasse: data["street"],
          plz: data["postal_code"],
          ort: data["city"],
          telefon1: data["phone_1"],
          telefon2: data["phone_2"],
          telefax: data["fax"]
        }
      end
    end

    nil
  rescue => e
    Rails.logger.warn "API Adresse #{address_nr} Fehler: #{e.message}"
    nil
  end

  # ============================================

  def build_position_data(item)
    {
      bezeichn1: item.bezeichn1,
      bezeichn2: item.bezeichn2,
      liefmenge: item.menge,
      einheit: item.einheit,
      artikelnr: item.artikelnr
    }
  end

  def build_address_data(address, item)
    return default_address_data unless address

    {
      name1: address[:name1] || item.kundname || "Unbekannt",
      name2: address[:name2],
      strasse: address[:strasse] || "",
      plz: address[:plz] || "",
      ort: address[:ort] || "",
      telefon1: address[:telefon1],
      telefon2: address[:telefon2],
      telefax: address[:telefax],
      lat: nil,
      lng: nil
    }
  end

  def default_address_data
    {
      name1: "Unbekannte Adresse",
      strasse: "Keine Adresse verfügbar",
      plz: "00000",
      ort: "Unbekannt",
      lat: nil,
      lng: nil
    }
  end

  def validate_positions_params(positions_params)
    unless positions_params.is_a?(Array)
      Rails.logger.error "positions_params is not an array: #{positions_params.class}"
      raise ActionController::ParameterMissing.new("Invalid positions format")
    end
  end

  def update_position_sequences(positions_params)
    Rails.logger.info "Updating sequence for #{positions_params.length} positions in tour #{@tour.id}"

    ActiveRecord::Base.transaction do
      @tour.delivery_items.update_all(sequence_number: nil)
      Rails.logger.info "Step 1: Set all sequence_numbers to NULL"

      positions_params.each do |position_data|
        update_single_position_sequence(position_data)
      end

      Rails.logger.info "Step 2: Set new sequence_numbers completed"
    end
  end

  def update_single_position_sequence(position_data)
    position_id = position_data[:position_id]
    sequence_number = position_data[:sequence_number]

    parts = position_id.split("-")
    if parts.length != 2
      Rails.logger.error "Invalid position_id format: #{position_id}"
      return
    end

    liefschnr = parts[0]
    posnr = parts[1].to_i

    item = @tour.delivery_items.find_by(liefschnr: liefschnr, posnr: posnr)

    if item
      item.update!(sequence_number: sequence_number)
      Rails.logger.info "Updated #{position_id} to sequence #{sequence_number}"
    else
      Rails.logger.warn "Item #{position_id} not found in tour #{@tour.id}"
    end
  end

  def assign_positions_to_tour(tour, position_ids)
    return 0 if position_ids.blank?

    assigned_count = 0

    position_ids.each do |position_id|
      parts = position_id.split("-")
      next if parts.length != 2

      liefschnr = parts[0]
      posnr = parts[1].to_i

      # Finde UnassignedDeliveryItem
      item = UnassignedDeliveryItem.find_by(liefschnr: liefschnr, posnr: posnr)

      unless item
        Rails.logger.warn "Item #{position_id} nicht gefunden"
        next
      end

      # Prüfen ob schon einer anderen Tour zugeordnet
      if item.tour_id.present? && item.tour_id != tour.id
        Rails.logger.warn "Item #{position_id} ist bereits Tour #{item.tour_id} zugeordnet"
        next
      end

      if item.assign_to_tour!(tour)
        sync_tour_assignment_to_firebird(item, tour)
        assigned_count += 1
        Rails.logger.info "✓ Item #{position_id} erfolgreich zu Tour #{tour.id} zugewiesen"
      end
    rescue => e
      Rails.logger.warn "Fehler beim Zuweisen von Item #{position_id}: #{e.message}"
    end

    # Automatisch Fahrzeug und Ladeort aus Positionen übernehmen
    tour.sync_defaults_from_positions! if assigned_count > 0

    assigned_count
  end

  def generate_tour_name
    count = Tour.where(tour_date: Date.current).count + 1
    "#{Date.current.strftime('%d.%m')} - #{count}"
  end

  def load_unassigned_delivery_items
    grouped_items = {}

    UnassignedDeliveryItem
      .for_display
      .where(tour_id: nil)
      .order(:planned_date, :liefschnr, :posnr)
      .find_each do |item|
      liefschnr = item.liefschnr

      if grouped_items[liefschnr].nil?
        # Erste Position dieses Lieferscheins - Kopfdaten anlegen
        grouped_items[liefschnr] = {
          liefschnr: liefschnr,
          typ: item.typ,
          customer_name: item.customer_name,
          delivery_address: item.delivery_address,
          delivery_date: item.delivery_date,
          planned_date: item.planned_date,
          planned_time: item.uhrzeit,
          lkwnr: item.lkwnr,
          fahrzeug: item.fahrzeug,
          ladeort: item.ladeort,
          total_weight: 0.0,
          positions: []
        }
      end

      # Position hinzufügen
      grouped_items[liefschnr][:positions] << {
        position_id: item.position_id,
        posnr: item.posnr,
        product_name: item.product_name,
        weight: item.weight_formatted,
        weight_raw: item.calculated_weight,
        quantity: item.quantity_with_unit,
        planning_notes: item.full_info_text
      }

      # Gesamtgewicht summieren
      grouped_items[liefschnr][:total_weight] += item.calculated_weight
    end

    # Als Array zurückgeben
    grouped_items.values
  end

  def sync_tour_assignment_to_firebird(item, tour)
    return unless item.tabelle_herkunft == "firebird_import"
    return unless tour.vehicle_id

    result = FirebirdWriteBackService.update_delivery_note_truck(
      item.liefschnr,
      tour.vehicle_id
    )

    unless result[:success]
      Rails.logger.error "Firebird Sync Fehler bei Tour-Zuweisung: #{result[:error]}"
    end
  end
end
