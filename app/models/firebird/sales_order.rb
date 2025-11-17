# frozen_string_literal: true

module Firebird
  class SalesOrder
    attr_accessor :vauftragnr, :datum, :kundennr, :kundname, :kundadrnr,
                  :rechnadrnr, :liefadrnr, :bestdatum, :bestnrkd,
                  :liefertext, :objekt, :geplliefdatum, :auftstatus,
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
        id: vauftragnr,
        sales_order_number: vauftragnr,
        date: datum,
        order_date: bestdatum,
        customer_number: kundennr,
        customer_name: kundname,
        customer_address_number: kundadrnr,
        billing_address_number: rechnadrnr,
        delivery_address_number: liefadrnr,
        customer_order_number: bestnrkd,
        delivery_text: liefertext,
        project: objekt,
        planned_delivery_date: geplliefdatum,
        status: auftstatus,
        net_amount: netto,
        gross_amount: brutto,
        sales_rep: vertreter,
        operator: bediener
      }
    end
  end
end
