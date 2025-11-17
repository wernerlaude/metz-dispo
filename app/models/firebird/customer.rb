# frozen_string_literal: true

module Firebird
  class Customer
    attr_accessor :kundennr, :kundgruppe, :rabatt, :zahlungart,
                  :umsatzsteuer, :gekuendigt

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
        id: kundennr,
        customer_number: kundennr,
        customer_group: kundgruppe,
        discount: rabatt,
        payment_method: zahlungart,
        vat_type: umsatzsteuer,
        terminated: gekuendigt
      }
    end
  end
end
