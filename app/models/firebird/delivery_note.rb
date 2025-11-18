# frozen_string_literal: true

module Firebird
  class DeliveryNote
    attr_accessor :liefschnr, :vauftragnr, :datum, :kundennr, :kundname,
                  :liefadrnr, :rechnadrnr, :geplliefdatum, :lkwnr,
                  :netto, :brutto, :vertreter, :bediener

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
        id: liefschnr,
        delivery_note_number: liefschnr,
        sales_order_number: vauftragnr,
        date: datum,
        customer_number: kundennr,
        customer_name: kundname,
        delivery_address_number: liefadrnr,
        billing_address_number: rechnadrnr,
        planned_delivery_date: geplliefdatum,
        vehicle_id: lkwnr,
        net_amount: netto,
        gross_amount: brutto,
        sales_rep: vertreter,
        operator: bediener
      }
    end
  end
end
