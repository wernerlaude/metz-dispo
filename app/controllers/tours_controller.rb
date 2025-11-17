class ToursController < ApplicationController
  before_action :set_tour, only: [ :update, :destroy, :details, :update_sequence ]

  def index
    @tours = load_tours
    @unassigned_deliveries = load_unassigned_delivery_items
  end

  # NEU: Manueller Refresh - nutzt Firebird Import
  def refresh_unassigned
    result = FirebirdDeliveryItemsImport.import!

    redirect_to root_path,
                notice: "#{result[:imported]} neue Positionen importiert, #{result[:updated]} aktualisiert, #{result[:skipped]} übersprungen"
  end

  def refresh_unassigned2
    result = FirebirdDeliveryItemsImport.import!
    session[:import_result] = result
    redirect_to root_path
  end

  def create
    @tour = Tour.create!(
      name: generate_tour_name,
      tour_date: Date.current
    )

    # Ausgewählte Positionen zuweisen
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

  def update
    if @tour.update(tour_params)
      redirect_to @tour, notice: "Tour wurde erfolgreich aktualisiert."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @tour.delivery_positions.any?
      redirect_to tours_path, alert: "Tour kann nicht gelöscht werden - enthält noch Lieferungen."
    else
      @tour.destroy
      redirect_to tours_path, notice: "Tour wurde gelöscht."
    end
  end

  def export_pdf
    @tour = Tour.find(params[:id])
    @positions = @tour.delivery_positions
                      .includes(delivery: [ :customer, :delivery_address ])
                      .order(:sequence_number, :liefschnr, :posnr)

    pdf = TourPdf.new(@tour, @positions)

    send_data pdf.render,
              filename: "Tour_#{@tour.name.to_s.gsub(/[^0-9A-Za-z.\-]/, '_')}_#{Date.current.strftime('%Y%m%d')}.pdf",
              type: "application/pdf",
              disposition: "attachment"
  end

  def details
    positions = load_tour_positions

    render json: {
      id: @tour.id,
      name: @tour.name || "Tour #{@tour.id}",
      date: @tour.tour_date&.strftime("%d.%m.%Y"),
      driver: build_driver_data,
      vehicle: build_vehicle_data,
      deliveries: positions.map { |position| build_delivery_data(position) }
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
    render json: { error: "Tour nicht gefunden" }, status: :not_found
  end

  def tour_params
    params.require(:tour).permit(:name, :tour_date, :vehicle, :driver_id, :loading_location_id, :notes, :tour_id)
  end

  def load_tours
    Tour.includes(:driver, :loading_location, :delivery_positions)
  end

  def load_tour_positions
    @tour.delivery_positions
         .includes(delivery: :delivery_address)
         .order(:sequence_number, :liefschnr, :posnr)
  end

  def build_driver_data
    {
      id: @tour.driver_id,
      name: @tour.driver&.full_name || (@tour.driver_id ? "Fahrer #{@tour.driver_id}" : "Kein Fahrer")
    }
  end

  def build_vehicle_data
    {
      name: @tour.vehicle || "Kein Fahrzeug"
    }
  end

  def build_delivery_data(position)
    delivery = position.delivery
    delivery_address = delivery&.delivery_address

    {
      id: "#{position.liefschnr}-#{position.posnr}",
      delivery_id: delivery&.liefschnr,
      sequence_number: position.sequence_number || 1,
      planned_time: delivery&.ladedatum&.strftime("%H:%M"),
      positions: [ build_position_data(position) ],
      delivery_address: build_address_data(delivery_address),
      selbstabholung: delivery&.selbstabholung,
      fruehbezug: delivery&.fruehbezug,
      gutschrift: delivery&.gutschrift,
      liefschnr: position.liefschnr
    }
  end

  def build_position_data(position)
    {
      bezeichn1: position.bezeichn1,
      bezeichn2: position.bezeichn2,
      liefmenge: position.liefmenge,
      einheit: position.einheit,
      artikelnr: position.artikelnr
    }
  end

  def build_address_data(delivery_address)
    return default_address_data unless delivery_address

    {
      name1: delivery_address.name1,
      name2: delivery_address.name2,
      strasse: delivery_address.strasse,
      plz: delivery_address.plz,
      ort: delivery_address.ort,
      telefon1: delivery_address.telefon1,
      telefon2: delivery_address.telefon2,
      telefax: delivery_address.telefax,
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
      @tour.delivery_positions.update_all(sequence_number: nil)
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

    position = @tour.delivery_positions.find_by(liefschnr: liefschnr, posnr: posnr)

    if position
      position.update!(sequence_number: sequence_number)
      Rails.logger.info "Updated #{position_id} to sequence #{sequence_number}"
    else
      Rails.logger.warn "Position #{position_id} not found in tour #{@tour.id}"
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

      # Finde Position und UnassignedDeliveryItem
      position = DeliveryPosition.find_by(liefschnr: liefschnr, posnr: posnr, tour: nil)
      unassigned_item = UnassignedDeliveryItem.find_by(liefschnr: liefschnr, posnr: posnr)

      if position&.update(tour: tour)
        # Markiere UnassignedDeliveryItem als assigned
        unassigned_item&.update(status: "assigned")

        # Sync LKW-Nummer zu Firebird wenn es ein Import-Item ist
        sync_tour_assignment_to_firebird(unassigned_item, tour) if unassigned_item

        assigned_count += 1
      else
        Rails.logger.warn "Fehler beim Zuweisen von Position #{position_id} zu Tour #{tour.id}"
      end
    end

    assigned_count
  end

  def build_creation_notice(tour, assigned_count, has_positions)
    base_message = "Neue Tour '#{tour.name}' wurde erstellt"

    return base_message + "." unless has_positions

    if assigned_count && assigned_count > 0
      base_message + " und #{assigned_count} Positionen wurden zugewiesen."
    else
      base_message + ", aber keine Positionen konnten zugewiesen werden."
    end
  end

  def generate_tour_name
    count = Tour.where(tour_date: Date.current).count + 1
    "#{Date.current.strftime('%d.%m')} - #{count}"
  end

  # Lädt aus unassigned_delivery_items Tabelle
  def load_unassigned_delivery_items
    delivery_items = []

    UnassignedDeliveryItem
      .for_display
      .order(:planned_date, :liefschnr, :posnr)
      .find_each do |item|
      delivery_items << {
        position_id: item.position_id,
        delivery_number: item.liefschnr,
        customer_name: item.customer_name,
        delivery_address: item.delivery_address,
        product_name: item.product_name,
        weight: item.weight_formatted,
        quantity: item.quantity_with_unit,
        delivery_date: item.delivery_date,
        planned_date: item.planned_date,
        planned_time: item.planned_time,
        planning_notes: item.planning_notes,
        vehicle: item.vehicle,
        delivery: item.delivery_position&.delivery,
        position: item.delivery_position
      }
    end

    delivery_items
  end

  # Sync Tour-Zuweisung zu Firebird
  def sync_tour_assignment_to_firebird(unassigned_item, tour)
    return unless unassigned_item.tabelle_herkunft == "firebird_import"
    return unless tour.truck_number

    result = FirebirdWriteBackService.update_delivery_note_truck(
      unassigned_item.liefschnr,
      tour.truck_number
    )

    unless result[:success]
      Rails.logger.error "Firebird Sync Fehler bei Tour-Zuweisung: #{result[:error]}"
    end
  end
end