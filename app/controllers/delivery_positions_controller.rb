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

    if tour_id.blank? || position_ids.empty?
      return render json: { success: false, message: "Tour oder Positionen fehlen" }, status: 422
    end

    tour = Tour.find(tour_id)
    success_count = 0
    errors = []

    position_ids.each do |position_id|
      begin
        last_dash_index = position_id.rindex("-")

        unless last_dash_index
          errors << "Ungültiges Position-ID Format: #{position_id}"
          next
        end

        liefschnr = position_id[0...last_dash_index]
        posnr = position_id[(last_dash_index + 1)..-1].to_i

        Rails.logger.info "Processing: #{liefschnr}-#{posnr}"

        position = DeliveryPosition.find_by(liefschnr: liefschnr, posnr: posnr)

        unless position
          Rails.logger.warn "Position nicht gefunden: #{position_id}"
          errors << "Position #{position_id} nicht gefunden"
          next
        end

        if position.tour.present?
          Rails.logger.warn "Position bereits zugewiesen: #{position_id} -> Tour #{position.tour_id}"
          errors << "Position #{position_id} ist bereits Tour #{position.tour.name} zugewiesen"
          next
        end

        # Zuweisen
        tour.add_position!(position)
        Rails.logger.info "✓ Position #{position_id} erfolgreich zugewiesen"

        # UnassignedDeliveryItem aktualisieren
        unassigned_item = UnassignedDeliveryItem.find_by(liefschnr: liefschnr, posnr: posnr)
        if unassigned_item
          unassigned_item.update(status: "assigned")
          Rails.logger.info "✓ UnassignedDeliveryItem #{position_id} -> assigned"

          # Firebird Write-Back
          sync_tour_assignment_to_firebird(unassigned_item, tour)
        else
          Rails.logger.info "ℹ Kein UnassignedDeliveryItem für #{position_id}"
        end

        success_count += 1
      rescue => e
        Rails.logger.error "✗ Fehler bei Position #{position_id}: #{e.message}"
        Rails.logger.error e.backtrace.first(5).join("\n")
        errors << "Fehler bei #{position_id}: #{e.message}"
      end
    end

    Rails.logger.info "=== Batch Assignment End: #{success_count}/#{position_ids.length} erfolgreich ==="

    if success_count > 0
      message = "#{success_count} Position(en) erfolgreich zugewiesen"
      message += ". Fehler: #{errors.join(', ')}" if errors.any?

      render json: { success: true, message: message, assigned_count: success_count }
    else
      error_message = errors.any? ? errors.join(", ") : "Keine Positionen konnten zugewiesen werden"
      render json: { success: false, message: error_message }, status: 422
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

      ActiveRecord::Base.transaction do
        # Step 1: Set temporary negative sequence numbers to avoid unique constraint violations
        tour.delivery_positions.find_each do |position|
          position.update_column(:sequence_number, -(position.sequence_number + 1000))
        end

        # Step 2: Set final sequence numbers in new order
        position_ids.each_with_index do |position_id, index|
          new_sequence = index + 1

          # Nimm das LETZTE "-" als Trenner
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
          else
            Rails.logger.warn "Position #{position_id} nicht in Tour #{tour_id} gefunden"
          end
        end
      end

      render json: {
        status: "success",
        message: "Reihenfolge von #{updated_count} Position(en) aktualisiert"
      }

    rescue ActiveRecord::RecordNotFound
      render json: { status: "error", message: "Tour nicht gefunden" }, status: 404

    rescue => e
      Rails.logger.error "Fehler beim Sortieren: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")

      render json: {
        status: "error",
        message: "Fehler beim Sortieren: #{e.message}"
      }, status: 500
    end
  end

  private

  def set_delivery_position
    position_id = params[:id]

    # Format: "LS141006-10" oder "LS141005-10-10"
    # Nimm das LETZTE "-" als Trenner zwischen liefschnr und posnr
    last_dash_index = position_id.rindex("-")

    if last_dash_index
      liefschnr = position_id[0...last_dash_index]
      posnr = position_id[(last_dash_index + 1)..-1].to_i

      @delivery_position = DeliveryPosition.find_by!(
        liefschnr: liefschnr,
        posnr: posnr
      )
    else
      # Fallback: Versuche als numerische ID
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
    return unless unassigned_item.tabelle_herkunft == "firebird_import"
    return unless tour.truck_number

    Rails.logger.info "→ Firebird Sync: #{unassigned_item.liefschnr} -> LKW #{tour.truck_number}"

    result = FirebirdWriteBackService.update_delivery_note_truck(
      unassigned_item.liefschnr,
      tour.truck_number
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
