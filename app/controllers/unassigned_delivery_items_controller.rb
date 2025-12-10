# app/controllers/unassigned_delivery_items_controller.rb
class UnassignedDeliveryItemsController < ApplicationController
  before_action :set_item, only: [:show, :update, :print_bestellung]

  # GET /unassigned_delivery_items/:id
  def show
    respond_to do |format|
      format.json { render json: item_as_json }
    end
  end

  # PATCH /unassigned_delivery_items/:id
  def update
    if @item.update(item_params)
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

  # GET /unassigned_delivery_items/:id/print_bestellung
  # GET /unassigned_delivery_items/:id/print_bestellung
  def print_bestellung
    delivery_data = build_delivery_data_for_print

    # Ladeort aus Parameter oder aus Position/Tour
    loading_location_name = params[:loading_location_name].presence ||
                            @item.ladeort.presence ||
                            @item.tour&.loading_location&.werk_name

    pdf = PositionBestellungPdf.new(
      @item,
      delivery_data: delivery_data,
      loading_location_name: loading_location_name
    )

    send_data pdf.render,
              filename: "Bestellung_#{@item.position_id}.pdf",
              type: "application/pdf",
              disposition: "inline"
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
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error "Position nicht gefunden: #{params[:id]} - #{e.message}"

    if request.format.json?
      render json: { error: "Position nicht gefunden" }, status: :not_found
    else
      redirect_to root_path, alert: "Position nicht gefunden"
    end
  end

  def item_params
    params.require(:unassigned_delivery_item).permit(
      :menge, :planned_date, :planned_time, :lkwnr, :kessel,
      :freight_price, :loading_price, :unloading_price,
      :kund_kommentar, :werk_kommentar, :planning_notes, :status
    )
  end

  def item_as_json
    {
      position_id: @item.position_id,
      liefschnr: @item.liefschnr,
      posnr: @item.posnr,
      vauftragnr: @item.vauftragnr,
      typ: @item.typ,
      customer_name: @item.customer_name,
      kundennr: @item.kundennr,
      kundname: @item.kundname,
      bezeichnung: @item.bezeichn1,
      bezeichn1: @item.bezeichn1,
      bezeichn2: @item.bezeichn2,
      artikel_nr: @item.artikelnr,
      menge: @item.menge,
      einheit: @item.einheit,
      gewicht: @item.gewicht,
      ladungsgewicht: @item.ladungsgewicht,
      calculated_weight: @item.calculated_weight,
      weight_formatted: @item.weight_formatted,
      total_weight: @item.calculated_weight,
      total_price: @item.total_price,
      brutto: @item.brutto,
      netto: @item.netto,
      planned_date: @item.planned_date&.to_s,
      planned_time: @item.planned_time&.to_s,
      geplliefdatum: @item.geplliefdatum&.to_s,
      uhrzeit: @item.uhrzeit,
      lkwnr: @item.lkwnr,
      fahrzeug: @item.fahrzeug,
      kessel: @item.kessel,
      vehicle_types: Vehicle.vehicle_types.map { |key, value|
        { value: value.to_s, label: Vehicle::VEHICLE_TYPE_LABELS[key] }
      },
      loading_address: @item.loading_address,
      ladeort: @item.ladeort,
      delivery_address: @item.delivery_address,
      liefadrnr: @item.liefadrnr,
      kundadrnr: @item.kundadrnr,
      kund_kommentar: @item.kund_kommentar,
      werk_kommentar: @item.werk_kommentar,
      planning_notes: @item.planning_notes,
      infoallgemein: @item.infoallgemein,
      infoverladung: @item.infoverladung,
      infoliefsch: @item.infoliefsch,
      liefertext: @item.liefertext,
      objekt: @item.objekt,
      bestnrkd: @item.bestnrkd,
      besteller: @item.besteller,
      status: @item.status,
      gedruckt: @item.gedruckt,
      invoiced: @item.invoiced
    }
  end

  def build_delivery_data_for_print
    address_nr = @item.liefadrnr || @item.kundadrnr
    address = load_address_for_print(address_nr)

    {
      delivery_address: address || {
        name1: @item.kundname,
        strasse: nil,
        plz: nil,
        ort: nil
      }
    }
  end

  def load_address_for_print(address_nr)
    return nil unless address_nr.present?

    if use_direct_connection?
      load_address_from_firebird(address_nr)
    else
      load_address_from_api(address_nr)
    end
  end

  def use_direct_connection?
    defined?(Firebird::Connection) && Firebird::Connection.instance.present?
  rescue
    false
  end

  def load_address_from_firebird(address_nr)
    return nil unless defined?(Firebird::Connection)

    conn = Firebird::Connection.instance
    rows = conn.query("SELECT * FROM ADRESSEN WHERE NUMMER = #{address_nr.to_i}")

    if rows.any?
      row = rows.first
      {
        name1: row["NAME1"]&.to_s&.strip,
        name2: row["NAME2"]&.to_s&.strip,
        strasse: row["STRASSE"]&.to_s&.strip,
        plz: row["PLZ"]&.to_s&.strip,
        ort: row["ORT"]&.to_s&.strip
      }
    end
  rescue => e
    Rails.logger.warn "Firebird Adresse #{address_nr} nicht gefunden: #{e.message}"
    nil
  end

  def load_address_from_api(address_nr)
    return nil unless defined?(FirebirdConnectApi)

    response = FirebirdConnectApi.get("/addresses/#{address_nr}")

    if response.success?
      parsed = JSON.parse(response.body)
      data = parsed["data"]

      if data
        {
          name1: data["name_1"],
          name2: data["name_2"],
          strasse: data["street"],
          plz: data["postal_code"],
          ort: data["city"]
        }
      end
    end
  rescue => e
    Rails.logger.warn "API Adresse #{address_nr} Fehler: #{e.message}"
    nil
  end

  def sync_to_firebird
    if @item.saved_change_to_menge?
      FirebirdWriteBackService.update_item_quantity(@item.liefschnr, @item.posnr, @item.menge)
    end

    if @item.saved_change_to_planned_date? && @item.planned_date.present?
      FirebirdWriteBackService.update_delivery_note_date(@item.liefschnr, @item.planned_date)
    end

    if @item.saved_change_to_lkwnr?
      FirebirdWriteBackService.update_delivery_note_truck(@item.liefschnr, @item.lkwnr)
    end
  end
end