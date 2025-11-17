class UnassignedDeliveryItemsController < ApplicationController
  before_action :set_item, only: [ :show, :update ]

  # GET /unassigned_delivery_items/:id
  # Liefert JSON-Daten für das Modal
  def show
    # Standard-Fahrzeug ohne Override
    standard_vehicle = @item.delivery_position&.delivery&.sales_order&.fahrzeug

    # Nur echtes Override senden (wenn es sich vom Standard unterscheidet)
    actual_override = if @item.vehicle_override.present? && @item.vehicle_override != standard_vehicle
                        @item.vehicle_override
    else
                        nil
    end

    render json: {
      id: @item.id,
      liefschnr: @item.liefschnr,
      posnr: @item.posnr,
      position_id: @item.position_id,

      # Produktdaten
      artikel_nr: @item.artikel_nr,
      bezeichnung: @item.product_name,
      menge: @item.menge,
      einheit: @item.einheit,

      # Preise
      freight_price: @item.freight_price,
      loading_price: @item.loading_price,
      unloading_price: @item.unloading_price,
      total_price: @item.total_price,

      # Planungsdaten
      planned_date: @item.planned_date,
      planned_time: @item.planned_time&.strftime("%H:%M"),
      beginn: @item.beginn,
      planning_notes: @item.planning_notes,

      # Fahrzeug & Transport
      vehicle: @item.vehicle,
      vehicle_override: actual_override,
      kessel: @item.kessel,

      # Adressen
      loading_address: @item.loading_address,
      loading_address_override: @item.loading_address_override,
      unloading_address: @item.delivery_address,
      unloading_address_override: @item.unloading_address_override,

      # Kommentare
      kund_kommentar: @item.kund_kommentar,
      werk_kommentar: @item.werk_kommentar,

      # Status
      status: @item.status,

      # Original Delivery Position für zusätzliche Infos
      delivery_position: @item.delivery_position ? {
        vauftragnr: @item.delivery_position.vauftragnr,
        artikelart: @item.delivery_position.artikelart
      } : nil,

      # Customer Info
      customer_name: @item.customer_name
    }
  end

  # PATCH /unassigned_delivery_items/:id
  # Speichert Änderungen
  def update
    if @item.update(item_params)
      # Sync zu Firebird wenn es ein Import-Item ist
      sync_to_firebird if @item.tabelle_herkunft == "firebird_import"

      render json: {
        success: true,
        message: "Position erfolgreich aktualisiert",
        item: {
          position_id: @item.position_id,
          menge: @item.menge,
          freight_price: @item.freight_price,
          loading_price: @item.loading_price,
          unloading_price: @item.unloading_price,
          total_price: @item.total_price,
          planned_date: @item.planned_date,
          planned_time: @item.planned_time&.strftime("%H:%M")
        }
      }
    else
      render json: {
        success: false,
        errors: @item.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  private

  def set_item
    position_id = params[:id]

    # ✅ FIX: Nimm das LETZTE "-" als Trenner
    # Format: "LS141006-10" oder "LS241001-10-10"
    last_dash_index = position_id.rindex("-")

    if last_dash_index
      liefschnr = position_id[0...last_dash_index]
      posnr = position_id[(last_dash_index + 1)..-1].to_i

      @item = UnassignedDeliveryItem.find_by!(
        liefschnr: liefschnr,
        posnr: posnr
      )
    else
      # Fallback: Versuche direkt als ID zu finden
      @item = UnassignedDeliveryItem.find(params[:id])
    end
  end

  def item_params
    params.require(:unassigned_delivery_item).permit(
      :menge,
      :freight_price,
      :loading_price,
      :unloading_price,
      :planned_date,
      :planned_time,
      :vehicle_override,
      :kessel,
      :loading_address_override,
      :unloading_address_override,
      :planning_notes,
      :kund_kommentar,
      :werk_kommentar
    )
  end

  # Sync zu Firebird
  def sync_to_firebird
    # Menge zurückschreiben
    if @item.saved_change_to_menge?
      result = FirebirdWriteBackService.update_item_quantity(
        @item.liefschnr,
        @item.posnr,
        @item.menge
      )

      unless result[:success]
        Rails.logger.error "Firebird Sync Fehler (Menge): #{result[:error]}"
      end
    end

    # Geplantes Lieferdatum zurückschreiben
    if @item.saved_change_to_planned_date? && @item.planned_date.present?
      result = FirebirdWriteBackService.update_delivery_note_date(
        @item.liefschnr,
        @item.planned_date
      )

      unless result[:success]
        Rails.logger.error "Firebird Sync Fehler (Datum): #{result[:error]}"
      end
    end
  end
end
