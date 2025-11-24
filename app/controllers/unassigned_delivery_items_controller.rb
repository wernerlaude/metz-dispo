# app/controllers/unassigned_delivery_items_controller.rb
class UnassignedDeliveryItemsController < ApplicationController
  before_action :set_item, only: [ :show, :update ]

  # GET /unassigned_delivery_items/:id
  # :id ist position_id im Format "liefschnr-posnr"
  def show
    respond_to do |format|
      format.json { render json: item_as_json }
    end
  end

  # PATCH /unassigned_delivery_items/:id
  def update
    if @item.update(item_params)
      # Optional: Write-back to Firebird
      sync_to_firebird if @item.tabelle_herkunft == "firebird_import"

      respond_to do |format|
        format.json { render json: { success: true, data: item_as_json } }
      end
    else
      respond_to do |format|
        format.json { render json: { success: false, errors: @item.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  private

  def set_item
    position_id = params[:id]
    parts = position_id.to_s.split("-")

    if parts.length >= 2
      liefschnr = parts[0]
      posnr = parts[1].to_i
      @item = UnassignedDeliveryItem.find_by!(liefschnr: liefschnr, posnr: posnr)
    else
      raise ActiveRecord::RecordNotFound, "Invalid position_id format"
    end
  rescue ActiveRecord::RecordNotFound
    respond_to do |format|
      format.json { render json: { error: "Position nicht gefunden" }, status: :not_found }
    end
  end

  def item_params
    params.require(:unassigned_delivery_item).permit(
      # Editierbare Felder
      :menge,
      :planned_date,
      :planned_time,
      :vehicle_override,
      :freight_price,
      :loading_price,
      :unloading_price,
      :kund_kommentar,
      :werk_kommentar,
      :planning_notes,
      :status
    )
  end

  def item_as_json
    {
      # Identifikation
      position_id: @item.position_id,
      liefschnr: @item.liefschnr,
      posnr: @item.posnr,
      vauftragnr: @item.vauftragnr,

      # Kunde
      customer_name: @item.customer_name,
      kundennr: @item.kundennr,
      kundname: @item.kundname,

      # Produkt
      bezeichnung: @item.bezeichn1,
      bezeichn1: @item.bezeichn1,
      bezeichn2: @item.bezeichn2,
      artikel_nr: @item.artikelnr,
      menge: @item.menge,
      einheit: @item.einheit,

      # Gewichte
      gewicht: @item.gewicht,
      ladungsgewicht: @item.ladungsgewicht,
      calculated_weight: @item.calculated_weight,

      # Preise
      freight_price: @item.freight_price,
      loading_price: @item.loading_price,
      unloading_price: @item.unloading_price,
      total_price: @item.total_price,
      brutto: @item.brutto,
      netto: @item.netto,

      # Planung
      planned_date: @item.planned_date&.to_s,
      planned_time: @item.planned_time&.to_s,
      geplliefdatum: @item.geplliefdatum&.to_s,
      uhrzeit: @item.uhrzeit,

      # Fahrzeug
      vehicle: @item.vehicle,
      vehicle_override: @item.vehicle_override,
      lkwnr: @item.lkwnr,
      fahrzeug: @item.fahrzeug,
      vehicles: available_vehicles,

      # Adressen
      loading_address: @item.loading_address,
      ladeort: @item.ladeort,
      delivery_address: @item.delivery_address,
      liefadrnr: @item.liefadrnr,
      kundadrnr: @item.kundadrnr,

      # Kommentare
      kund_kommentar: @item.kund_kommentar,
      werk_kommentar: @item.werk_kommentar,
      planning_notes: @item.planning_notes,

      # Infotexte aus Firebird
      infoallgemein: @item.infoallgemein,
      infoverladung: @item.infoverladung,
      infoliefsch: @item.infoliefsch,
      liefertext: @item.liefertext,

      # Projekt/Bestellung
      objekt: @item.objekt,
      bestnrkd: @item.bestnrkd,
      besteller: @item.besteller,

      # Status
      status: @item.status,
      gedruckt: @item.gedruckt,
      invoiced: @item.invoiced
    }
  end

  def available_vehicles
    # Hole verfügbare Fahrzeuge
    if defined?(Vehicle)
      Vehicle.pluck(:license_plate).compact
    else
      []
    end
  end

  def sync_to_firebird
    # Sync Menge zurück zu Firebird wenn geändert
    if @item.saved_change_to_menge?
      FirebirdWriteBackService.update_item_quantity(
        @item.liefschnr,
        @item.posnr,
        @item.menge
      )
    end

    # Sync geplantes Datum
    if @item.saved_change_to_planned_date? && @item.planned_date.present?
      FirebirdWriteBackService.update_delivery_note_date(
        @item.liefschnr,
        @item.planned_date
      )
    end
  end
end
