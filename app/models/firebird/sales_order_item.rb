# frozen_string_literal: true

# app/models/firebird/sales_order_item.rb
module Firebird
  class SalesOrderItem
    attr_accessor :vauftragnr, :posnr, :posart, :artikelnr, :bezeichn1,
                  :bezeichn2, :langtext, :artikelart, :langzusaet,
                  :langliefer, :langrechn, :umsatzgrp,
                  :menge, :bishliefmg, :einhschl, :einheit, :preiseinh,
                  :gebindemg, :gebindschl, :gebindeinh, :gebinhalt,
                  :listpreis, :listbrutto, :rabatt, :rabattart,
                  :einhpreis, :bruttpreis, :netto, :mwst, :brutto,
                  :steuerschl, :mwstsatz,
                  :listpreis2, :listbrutto2, :einhpreis2, :bruttpreis2,
                  :netto2, :mwst2, :brutto2, :rabatt2, :rabattart2,
                  :zuabschlagnr, :zuabschlagnr2,
                  :lager, :abteilung, :lagerfach, :chargennr, :seriennr,
                  :gewicht, :ladungsgewicht,
                  :palettennr, :palanzahl,
                  :rezepturnr, :rezepturnr2, :prod_erledigt, :ruestliste,
                  :produktionsauftragid, :prodanlage, :vorprodanlage

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
        sales_order_number: vauftragnr,
        position: posnr,
        position_type: posart,

        # Artikel
        article_number: artikelnr,
        article_type: artikelart,
        description_1: bezeichn1,
        description_2: bezeichn2,
        long_text: langtext,
        long_additions: langzusaet,
        long_delivery: langliefer,
        long_invoice: langrechn,
        revenue_group: umsatzgrp,

        # Mengen
        quantity: menge,
        delivered_quantity: bishliefmg,
        unit_key: einhschl,
        unit: einheit,
        price_unit: preiseinh,

        # Gebinde
        container_quantity: gebindemg,
        container_key: gebindschl,
        container_unit: gebindeinh,
        container_content: gebinhalt,

        # Gewichte
        weight: gewicht,
        loading_weight: ladungsgewicht,

        # Paletten
        pallet_number: palettennr,
        pallet_count: palanzahl,

        # Preise (Primär)
        list_price: listpreis,
        list_gross: listbrutto,
        unit_price: einhpreis,
        gross_price: bruttpreis,
        net_amount: netto,
        vat: mwst,
        gross_amount: brutto,
        discount: rabatt,
        discount_type: rabattart,
        tax_key: steuerschl,
        vat_rate: mwstsatz,

        # Preise (Sekundär/Fremdwährung)
        list_price_2: listpreis2,
        list_gross_2: listbrutto2,
        unit_price_2: einhpreis2,
        gross_price_2: bruttpreis2,
        net_amount_2: netto2,
        vat_2: mwst2,
        gross_amount_2: brutto2,
        discount_2: rabatt2,
        discount_type_2: rabattart2,

        # Zu-/Abschläge
        surcharge_number: zuabschlagnr,
        surcharge_number_2: zuabschlagnr2,

        # Lager
        warehouse: lager,
        department: abteilung,
        storage_bin: lagerfach,
        batch_number: chargennr,
        serial_number: seriennr,

        # Produktion
        recipe_number: rezepturnr,
        recipe_number_2: rezepturnr2,
        production_completed: prod_erledigt,
        setup_list: ruestliste,
        production_order_id: produktionsauftragid,
        production_facility: prodanlage,
        pre_production_facility: vorprodanlage
      }
    end
  end
end
