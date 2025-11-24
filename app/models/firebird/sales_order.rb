# frozen_string_literal: true

# app/models/firebird/sales_order.rb
module Firebird
  class SalesOrder
    attr_accessor :vauftragnr, :datum, :bediener, :vertreter, :kostenst,
                  :kundennr, :debitorkto, :kundname, :kundadrnr, :rechnadrnr,
                  :liefadrnr, :gebiet, :best_anrede, :best_briefanrede,
                  :besteller, :bestdatum, :bestnrkd, :kdabteilung,
                  :angebotnr, :angebdatum, :liefertext, :objekt, :lieferart,
                  :waehrcode, :kundwaehrcode, :mwstkz,
                  :skonto1tg, :skonto1pr, :skonto2tg, :skonto2pr,
                  :nettotg, :valuta, :lastschrift, :zahlbedtext,
                  :erledigt, :auftstatus, :auftrbestgedruckt, :betrauftrgedruckt,
                  :geplliefjahrkw, :geplliefdatum, :verzgrund,
                  :lager, :lkwnr, :selbstabhrabatt, :spediteurnr,
                  :fahrzeug, :containernr, :transportart, :ladeort,
                  :prodtermin, :ladetermin, :ladedatum,
                  :kfzkennzeichen1, :kfzkennzeichen2, :uhrzeit,
                  :infoallgemein, :infoproduktion, :infoverladung,
                  :infoliefsch, :infoauftrbest,
                  :fremdwaehrung, :umrfaktor, :bruttoberechn,
                  :geaendertam, :vertragstyp, :versandart,
                  :netto, :brutto

    def initialize(attributes = {})
      attributes.each do |key, value|
        setter = "#{key.downcase}="
        send(setter, value) if respond_to?(setter)
      end
    end

    def self.from_firebird_row(row)
      new(row)
    end

    def as_json(options = {})
      {
        # Identifikation
        id: vauftragnr,
        sales_order_number: vauftragnr,

        # Datum
        date: datum,
        order_date: bestdatum,
        offer_date: angebdatum,
        planned_delivery_date: geplliefdatum,
        planned_delivery_week: geplliefjahrkw,
        production_date: prodtermin,
        loading_deadline: ladetermin,
        loading_date: ladedatum,
        modified_at: geaendertam,

        # Kunde
        customer_number: kundennr,
        customer_name: kundname,
        debitor_account: debitorkto,
        customer_department: kdabteilung,
        region: gebiet,

        # Adressen
        customer_address_number: kundadrnr,
        billing_address_number: rechnadrnr,
        delivery_address_number: liefadrnr,

        # Bestellung
        customer_order_number: bestnrkd,
        orderer: besteller,
        orderer_salutation: best_anrede,
        orderer_letter_salutation: best_briefanrede,
        offer_number: angebotnr,

        # Transport/Logistik
        delivery_type: lieferart,
        shipping_type: versandart,
        transport_type: transportart,
        loading_location: ladeort,
        vehicle_number: lkwnr,
        vehicle_type: fahrzeug,
        container_number: containernr,
        forwarder_number: spediteurnr,
        license_plate_1: kfzkennzeichen1,
        license_plate_2: kfzkennzeichen2,
        time: uhrzeit,

        # Texte
        delivery_text: liefertext,
        project: objekt,
        info_general: infoallgemein,
        info_production: infoproduktion,
        info_loading: infoverladung,
        info_delivery_note: infoliefsch,
        info_order_confirmation: infoauftrbest,
        payment_terms_text: zahlbedtext,
        delay_reason: verzgrund,

        # Status
        status: auftstatus,
        completed: erledigt,
        order_confirmation_printed: auftrbestgedruckt,
        operating_order_printed: betrauftrgedruckt,
        contract_type: vertragstyp,

        # Beträge
        net_amount: netto,
        gross_amount: brutto,

        # Zahlungsbedingungen
        discount_1_days: skonto1tg,
        discount_1_percent: skonto1pr,
        discount_2_days: skonto2tg,
        discount_2_percent: skonto2pr,
        net_days: nettotg,
        value_date: valuta,
        direct_debit: lastschrift,
        self_pickup_discount: selbstabhrabatt,

        # Währung
        currency_code: waehrcode,
        customer_currency_code: kundwaehrcode,
        foreign_currency: fremdwaehrung,
        exchange_rate: umrfaktor,
        vat_key: mwstkz,
        gross_calculation: bruttoberechn,

        # Lager
        warehouse: lager,
        cost_center: kostenst,

        # Bearbeiter
        operator: bediener,
        sales_rep: vertreter
      }
    end
  end
end
