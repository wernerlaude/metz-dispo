class DeliveryPositionsController < ApplicationController
  before_action :set_delivery_position, only: [ :show, :edit, :update, :destroy, :assign, :unassign, :move_up, :move_down, :details ]

  def index
    @delivery_positions = DeliveryPosition.includes(delivery: [ :customer, :sales_order ])
                                          .page(params[:page])
  end

  def show
    @delivery_position = @delivery_position
  end

  def new
    @delivery_position = DeliveryPosition.new
  end

  def create
    @delivery_position = DeliveryPosition.new(delivery_position_params)

    if @delivery_position.save
      redirect_to @delivery_position, notice: "Position wurde erfolgreich erstellt."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @delivery_position.update(delivery_position_params)
      redirect_to @delivery_position, notice: "Position wurde erfolgreich aktualisiert."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @delivery_position.destroy
    redirect_to delivery_positions_path, notice: "Position wurde gelöscht."
  end

  # MEMBER ACTIONS

  def assign
    tour = Tour.find(params[:tour_id])

    begin
      tour.add_position!(@delivery_position)

      # UnassignedDeliveryItem aktualisieren und Firebird Sync
      unassigned_item = UnassignedDeliveryItem.find_by(
        liefschnr: @delivery_position.liefschnr,
        posnr: @delivery_position.posnr
      )

      if unassigned_item
        unassigned_item.update(status: "assigned")
        sync_tour_assignment_to_firebird(unassigned_item, tour)
      end

      respond_to do |format|
        format.json { render json: { success: true, message: "Position zugewiesen" } }
        format.html do
          flash[:notice] = "Position zugewiesen"
          redirect_back_or_to tours_path
        end
      end
    rescue => e
      respond_to do |format|
        format.json { render json: { success: false, message: e.message }, status: 422 }
        format.html do
          flash[:alert] = e.message
          redirect_back_or_to tours_path
        end
      end
    end
  end

  def unassign
    begin
      tour = @delivery_position.tour
      tour.remove_position!(@delivery_position) if tour

      # UnassignedDeliveryItem zurücksetzen
      unassigned_item = UnassignedDeliveryItem.find_by(
        liefschnr: @delivery_position.liefschnr,
        posnr: @delivery_position.posnr
      )
      unassigned_item&.update(status: "ready")

      respond_to do |format|
        format.json { render json: { success: true, message: "Position entfernt" } }
        format.html do
          flash[:notice] = "Position entfernt"
          redirect_back_or_to tours_path
        end
      end
    rescue => e
      respond_to do |format|
        format.json { render json: { success: false, message: e.message }, status: 422 }
        format.html do
          flash[:alert] = e.message
          redirect_back_or_to tours_path
        end
      end
    end
  end

  def move_up
    return unless @delivery_position.tour && @delivery_position.sequence_number > 1

    tour = @delivery_position.tour
    current_sequence = @delivery_position.sequence_number

    position_above = tour.delivery_positions.find_by(sequence_number: current_sequence - 1)

    if position_above
      ActiveRecord::Base.transaction do
        position_above.update!(sequence_number: current_sequence)
        @delivery_position.update!(sequence_number: current_sequence - 1)
      end
    end

    redirect_back_or_to tour_path(tour)
  end

  def move_down
    return unless @delivery_position.tour

    tour = @delivery_position.tour
    current_sequence = @delivery_position.sequence_number
    max_sequence = tour.delivery_positions.maximum(:sequence_number)

    return if current_sequence >= max_sequence

    position_below = tour.delivery_positions.find_by(sequence_number: current_sequence + 1)

    if position_below
      ActiveRecord::Base.transaction do
        position_below.update!(sequence_number: current_sequence)
        @delivery_position.update!(sequence_number: current_sequence + 1)
      end
    end

    redirect_back_or_to tour_path(tour)
  end

  def details
    respond_to do |format|
      format.json {
        render json: @delivery_position.as_json(
          include: {
            delivery: {
              include: [ :customer, :delivery_address, :customer_address, :billing_address ],
              methods: [ :delivery_address_formatted, :customer_address_formatted ]
            },
            tour: {
              include: :driver
            }
          },
          methods: [ :weight_formatted, :quantity_with_unit, :customer_name ]
        )
      }
    end
  end

  # COLLECTION ACTIONS

  def assign_multiple
    tour_id = params[:tour_id]
    position_ids = params[:position_ids] || []

    tour = Tour.find(tour_id)

    Rails.logger.info "=== Batch Assignment Start: #{position_ids.length} positions to tour #{tour.id} ==="

    success_count = 0
    failed = []

    position_ids.each do |position_id|
      Rails.logger.info "Processing: #{position_id}"

      parts = position_id.split("-")
      if parts.length != 2
        Rails.logger.warn "Invalid position_id format: #{position_id}"
        failed << position_id
        next
      end

      liefschnr = parts[0]
      posnr = parts[1].to_i

      # Zuerst UnassignedDeliveryItem finden
      unassigned_item = UnassignedDeliveryItem.find_by(liefschnr: liefschnr, posnr: posnr)

      # DeliveryPosition finden oder erstellen
      position = DeliveryPosition.find_by(liefschnr: liefschnr, posnr: posnr)

      # Falls keine DeliveryPosition existiert, erstelle eine aus UnassignedDeliveryItem
      if position.nil? && unassigned_item.present?
        Rails.logger.info "Creating DeliveryPosition from UnassignedDeliveryItem: #{position_id}"
        position = create_delivery_position_from_unassigned(unassigned_item)
      end

      if position
        # Prüfen ob schon einer anderen Tour zugeordnet
        if position.tour_id.present? && position.tour_id != tour.id
          Rails.logger.warn "Position #{position_id} ist bereits Tour #{position.tour_id} zugeordnet"
          failed << position_id
          next
        end

        # Position der Tour zuordnen
        if position.update(tour_id: tour.id, sequence_number: nil)
          # UnassignedDeliveryItem Status aktualisieren
          unassigned_item&.update(status: "assigned")

          # Firebird Sync
          sync_tour_assignment_to_firebird(unassigned_item, tour) if unassigned_item

          success_count += 1
          Rails.logger.info "✓ Position #{position_id} erfolgreich zugewiesen"
        else
          Rails.logger.error "✗ Fehler beim Update von Position #{position_id}: #{position.errors.full_messages}"
          failed << position_id
        end
      else
        Rails.logger.error "✗ Position nicht gefunden und konnte nicht erstellt werden: #{position_id}"
        failed << position_id
      end
    end

    Rails.logger.info "=== Batch Assignment End: #{success_count}/#{position_ids.length} erfolgreich ==="

    if success_count > 0
      render json: {
        success: true,
        message: "#{success_count} Position(en) zur Tour hinzugefügt",
        assigned_count: success_count,
        failed_count: failed.length,
        failed_ids: failed
      }
    else
      render json: {
        success: false,
        message: "Keine Positionen konnten zugewiesen werden",
        failed_ids: failed
      }, status: :unprocessable_entity
    end
  end

  def unassigned
    @delivery_positions = DeliveryPosition.unassigned
                                          .includes(delivery: [ :customer, :sales_order ])
                                          .joins(:delivery)
                                          .where(wws_vliefer1: { gedruckt: false, selbstabholung: [ false, nil ] })
                                          .order("wws_vliefer1.ladedatum", "wws_vliefer1.kundname", :posnr)

    respond_to do |format|
      format.html
      format.json { render json: @delivery_positions.as_json(include: :delivery) }
    end
  end

  def reorder_in_tour
    tour_id = params[:tour_id]
    position_ids = params[:position_ids] || []

    if tour_id.blank? || position_ids.empty?
      return render json: { status: "error", message: "Tour ID oder Position IDs fehlen" }, status: 422
    end

    begin
      tour = Tour.find(tour_id)
      updated_count = 0

      Rails.logger.info "=== Reorder Start: Tour #{tour_id} ==="
      Rails.logger.info "Position IDs: #{position_ids.inspect}"

      ActiveRecord::Base.transaction do
        tour.delivery_positions.update_all(sequence_number: nil)
        Rails.logger.info "✓ Reset all sequence_numbers to nil"

        position_ids.each_with_index do |position_id, index|
          new_sequence = index + 1

          last_dash_index = position_id.rindex("-")
          next unless last_dash_index

          liefschnr = position_id[0...last_dash_index]
          posnr = position_id[(last_dash_index + 1)..-1].to_i

          position = tour.delivery_positions.find_by(
            liefschnr: liefschnr,
            posnr: posnr
          )

          if position
            position.update_column(:sequence_number, new_sequence)
            updated_count += 1
            Rails.logger.info "✓ Updated #{position_id} to sequence #{new_sequence}"
          else
            Rails.logger.warn "⚠️ Position #{position_id} not found in tour #{tour_id}"
          end
        end
      end

      Rails.logger.info "=== Reorder Complete: #{updated_count} positions updated ==="

      render json: {
        status: "success",
        success: true,
        message: "Reihenfolge von #{updated_count} Position(en) aktualisiert",
        updated_count: updated_count
      }

    rescue ActiveRecord::RecordNotFound
      render json: { status: "error", message: "Tour nicht gefunden" }, status: 404

    rescue StandardError => e
      Rails.logger.error "❌ Fehler beim Sortieren: #{e.message}"
      Rails.logger.error e.backtrace.first(10).join("\n")

      render json: {
        status: "error",
        success: false,
        message: "Fehler beim Sortieren: #{e.message}"
      }, status: 500
    end
  end

  private

  def set_delivery_position
    position_id = params[:id]

    last_dash_index = position_id.rindex("-")

    if last_dash_index
      liefschnr = position_id[0...last_dash_index]
      posnr = position_id[(last_dash_index + 1)..-1].to_i

      @delivery_position = DeliveryPosition.find_by!(
        liefschnr: liefschnr,
        posnr: posnr
      )
    else
      @delivery_position = DeliveryPosition.find(params[:id])
    end
  rescue ActiveRecord::RecordNotFound
    Rails.logger.error "DeliveryPosition nicht gefunden: #{position_id}"

    respond_to do |format|
      format.json { render json: { error: "Position nicht gefunden" }, status: :not_found }
      format.html do
        flash[:alert] = "Position nicht gefunden"
        redirect_to delivery_positions_path
      end
    end
  end

  def delivery_position_params
    params.require(:delivery_position).permit(
      :liefschnr,
      :posnr,
      :artikelnr,
      :bezeichn1,
      :bezeichn2,
      :liefmenge,
      :einheit,
      :tour_id,
      :sequence_number,
      :einhpreis,
      :termin,
      :info
    )
  end

  # Erstelle DeliveryPosition aus UnassignedDeliveryItem
  def create_delivery_position_from_unassigned(unassigned_item)
    # Zuerst prüfen ob Delivery existiert, sonst erstellen
    delivery = Delivery.find_by(liefschnr: unassigned_item.liefschnr)

    unless delivery
      delivery = Delivery.create!(
        liefschnr: unassigned_item.liefschnr,
        vauftragnr: unassigned_item.vauftragnr,
        kundennr: unassigned_item.kundennr,
        kundname: unassigned_item.kundname,
        kundadrnr: unassigned_item.kundadrnr,
        liefadrnr: unassigned_item.liefadrnr,
        datum: unassigned_item.geplliefdatum || Date.current,
        geplliefdatum: unassigned_item.geplliefdatum,
        ladedatum: unassigned_item.ladedatum
      )
      Rails.logger.info "✓ Delivery erstellt: #{delivery.liefschnr}"
    end

    # DeliveryPosition erstellen
    position = DeliveryPosition.create!(
      liefschnr: unassigned_item.liefschnr,
      posnr: unassigned_item.posnr,
      artikelnr: unassigned_item.artikelnr,
      bezeichn1: unassigned_item.bezeichn1,
      bezeichn2: unassigned_item.bezeichn2,
      liefmenge: unassigned_item.menge,
      einheit: unassigned_item.einheit
    )

    Rails.logger.info "✓ DeliveryPosition erstellt: #{position.liefschnr}-#{position.posnr}"
    position
  rescue => e
    Rails.logger.error "✗ Fehler beim Erstellen von DeliveryPosition: #{e.message}"
    nil
  end

  def load_unassigned_delivery_items
    delivery_items = []

    DeliveryPosition
      .includes(delivery: [ :customer, :sales_order ])
      .unassigned
      .joins(:delivery)
      .where(wws_vliefer1: { gedruckt: false, selbstabholung: [ false, nil ] })
      .order("wws_vliefer1.ladedatum", "wws_vliefer1.kundname", :posnr)
      .find_each do |position|
      delivery_items << {
        position_id: "#{position.liefschnr}-#{position.posnr}",
        delivery_number: position.delivery.delivery_number,
        customer_name: position.customer_name,
        delivery_address: "Adresse wird geladen...",
        product_name: position.product_name,
        weight: position.weight_formatted,
        quantity: position.quantity_with_unit,
        delivery_date: position.delivery.delivery_date,
        vehicle: position.delivery.sales_order&.fahrzeug,
        delivery: position.delivery,
        position: position
      }
    end

    delivery_items
  end

  # Sync Tour-Zuweisung zu Firebird
  def sync_tour_assignment_to_firebird(unassigned_item, tour)
    return unless unassigned_item&.tabelle_herkunft == "firebird_import"
    return unless tour.vehicle_id

    Rails.logger.info "→ Firebird Sync: #{unassigned_item.liefschnr} -> LKW #{tour.vehicle_id}"

    result = FirebirdWriteBackService.update_delivery_note_truck(
      unassigned_item.liefschnr,
      tour.vehicle_id
    )

    if result[:success]
      Rails.logger.info "✓ Firebird Sync erfolgreich"
    else
      Rails.logger.error "✗ Firebird Sync Fehler: #{result[:error]}"
    end
  rescue => e
    Rails.logger.error "✗ Firebird Sync Exception: #{e.message}"
  end
end
