# frozen_string_literal: true

module Firebird
  class SalesOrderItem
    attr_accessor :vauftragnr, :posnr, :posart, :artikelnr, :bezeichn1,
                  :bezeichn2, :menge, :einheit, :einhpreis, :netto,
                  :mwst, :brutto, :rabatt, :gewicht

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
        sales_order_number: vauftragnr,
        position: posnr,
        position_type: posart,
        article_number: artikelnr,
        description_1: bezeichn1,
        description_2: bezeichn2,
        quantity: menge,
        unit: einheit,
        unit_price: einhpreis,
        net_amount: netto,
        vat: mwst,
        gross_amount: brutto,
        discount: rabatt,
        weight: gewicht
      }
    end
  end
end
