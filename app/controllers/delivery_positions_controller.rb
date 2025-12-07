# app/controllers/delivery_positions_controller.rb
class DeliveryPositionsController < ApplicationController
  before_action :set_item, only: [ :show, :edit, :update, :destroy, :assign, :unassign, :move_up, :move_down, :details ]

  def index
    @delivery_positions = UnassignedDeliveryItem.order(:liefschnr, :posnr).page(params[:page])
  end

  def show
  end

  def new
    @delivery_position = UnassignedDeliveryItem.new
  end

  def create
    @delivery_position = UnassignedDeliveryItem.new(item_params)

    if @delivery_position.save
      redirect_to delivery_positions_path, notice: "Position wurde erfolgreich erstellt."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @item.update(item_params)
      redirect_to delivery_positions_path, notice: "Position wurde erfolgreich aktualisiert."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @item.destroy
    redirect_to delivery_positions_path, notice: "Position wurde gelöscht."
  end

  # MEMBER ACTIONS

  def assign
    tour = Tour.find(params[:tour_id])

    begin
      if @item.update(tour: tour, status: "assigned")
        sync_tour_assignment_to_firebird(@item, tour)

        respond_to do |format|
          format.json { render json: { success: true, message: "Position zugewiesen" } }
          format.html do
            flash[:notice] = "Position zugewiesen"
            redirect_back_or_to tours_path
          end
        end
      else
        raise "Konnte Position nicht zuweisen"
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
    @tour = @item.tour  # Tour merken bevor wir sie entfernen

    begin
      if @item.update(tour_id: nil, status: "ready", sequence_number: nil)
        respond_to do |format|
          format.turbo_stream do
            if @tour
              render turbo_stream: turbo_stream.replace(
                "tour_#{@tour.id}",
                partial: "tours/tour_card",
                locals: { tour: @tour.reload }
              )
            else
              head :ok
            end
          end
          format.json { render json: { success: true, message: "Position entfernt" } }
          format.html do
            flash[:notice] = "Position entfernt"
            redirect_back_or_to tours_path
          end
        end
      else
        raise "Konnte Position nicht entfernen"
      end
    rescue => e
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.prepend("flash", partial: "shared/flash", locals: { alert: e.message })
        end
        format.json { render json: { success: false, message: e.message }, status: 422 }
        format.html do
          flash[:alert] = e.message
          redirect_back_or_to tours_path
        end
      end
    end
  end

  def move_up
    return unless @item.tour && @item.sequence_number && @item.sequence_number > 1

    tour = @item.tour
    current_sequence = @item.sequence_number

    item_above = tour.delivery_items.find_by(sequence_number: current_sequence - 1)

    if item_above
      ActiveRecord::Base.transaction do
        item_above.update!(sequence_number: current_sequence)
        @item.update!(sequence_number: current_sequence - 1)
      end
    end

    redirect_back_or_to tours_path
  end

  def move_down
    return unless @item.tour

    tour = @item.tour
    current_sequence = @item.sequence_number
    max_sequence = tour.delivery_items.maximum(:sequence_number)

    return if current_sequence.nil? || current_sequence >= max_sequence.to_i

    item_below = tour.delivery_items.find_by(sequence_number: current_sequence + 1)

    if item_below
      ActiveRecord::Base.transaction do
        item_below.update!(sequence_number: current_sequence)
        @item.update!(sequence_number: current_sequence + 1)
      end
    end

    redirect_back_or_to tours_path
  end

  def details
    respond_to do |format|
      format.json {
        render json: {
          liefschnr: @item.liefschnr,
          posnr: @item.posnr,
          artikelnr: @item.artikelnr,
          bezeichn1: @item.bezeichn1,
          bezeichn2: @item.bezeichn2,
          menge: @item.menge,
          einheit: @item.einheit,
          gewicht: @item.gewicht,
          kundname: @item.kundname,
          customer_name: @item.customer_name,
          delivery_address: @item.delivery_address,
          weight_formatted: @item.weight_formatted,
          quantity_with_unit: @item.quantity_with_unit
        }
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

      item = UnassignedDeliveryItem.find_by(liefschnr: liefschnr, posnr: posnr)

      if item
        # Prüfen ob schon einer anderen Tour zugeordnet
        if item.tour_id.present? && item.tour_id != tour.id
          Rails.logger.warn "Item #{position_id} ist bereits Tour #{item.tour_id} zugeordnet"
          failed << position_id
          next
        end

        # Item der Tour zuordnen
        if item.update(tour_id: tour.id, status: "assigned", sequence_number: nil)
          sync_tour_assignment_to_firebird(item, tour)
          success_count += 1
          Rails.logger.info "✓ Item #{position_id} erfolgreich zugewiesen"
        else
          Rails.logger.error "✗ Fehler beim Update von Item #{position_id}: #{item.errors.full_messages}"
          failed << position_id
        end
      else
        Rails.logger.error "✗ Item nicht gefunden: #{position_id}"
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
    @delivery_positions = UnassignedDeliveryItem.for_display
                                                .where(tour_id: nil)
                                                .order(:geplliefdatum, :kundname, :posnr)

    respond_to do |format|
      format.html
      format.json { render json: @delivery_positions }
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
        tour.delivery_items.update_all(sequence_number: nil)
        Rails.logger.info "✓ Reset all sequence_numbers to nil"

        position_ids.each_with_index do |position_id, index|
          new_sequence = index + 1

          parts = position_id.split("-")
          next if parts.length != 2

          liefschnr = parts[0]
          posnr = parts[1].to_i

          item = tour.delivery_items.find_by(liefschnr: liefschnr, posnr: posnr)

          if item
            item.update_column(:sequence_number, new_sequence)
            updated_count += 1
            Rails.logger.info "✓ Updated #{position_id} to sequence #{new_sequence}"
          else
            Rails.logger.warn "⚠️ Item #{position_id} not found in tour #{tour_id}"
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

  def set_item
    position_id = params[:id]

    parts = position_id.split("-")

    if parts.length == 2
      liefschnr = parts[0]
      posnr = parts[1].to_i

      @item = UnassignedDeliveryItem.find_by!(liefschnr: liefschnr, posnr: posnr)
    else
      @item = UnassignedDeliveryItem.find(params[:id])
    end
  rescue ActiveRecord::RecordNotFound
    Rails.logger.error "Item nicht gefunden: #{position_id}"

    respond_to do |format|
      format.json { render json: { error: "Position nicht gefunden" }, status: :not_found }
      format.html do
        flash[:alert] = "Position nicht gefunden"
        redirect_to tours_path
      end
    end
  end

  def item_params
    params.require(:unassigned_delivery_item).permit(
      :liefschnr,
      :posnr,
      :artikelnr,
      :bezeichn1,
      :bezeichn2,
      :menge,
      :einheit,
      :tour_id,
      :sequence_number
    )
  end

  # Sync Tour-Zuweisung zu Firebird
  def sync_tour_assignment_to_firebird(item, tour)
    return unless item&.tabelle_herkunft == "firebird_import"
    return unless tour.vehicle_id

    Rails.logger.info "→ Firebird Sync: #{item.liefschnr} -> LKW #{tour.vehicle_id}"

    result = FirebirdWriteBackService.update_delivery_note_truck(
      item.liefschnr,
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