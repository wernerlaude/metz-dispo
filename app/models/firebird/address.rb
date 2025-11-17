# frozen_string_literal: true

module Firebird
  class Address
    attr_accessor :nummer, :name1, :name2, :strasse, :plz, :ort,
                  :land, :telefon1, :telefon2, :telefax, :email,
                  :homepage, :anrede, :briefanr

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
        id: nummer,
        address_number: nummer,
        name_1: name1,
        name_2: name2,
        street: strasse,
        postal_code: plz,
        city: ort,
        country: land,
        phone_1: telefon1,
        phone_2: telefon2,
        fax: telefax,
        email: email,
        website: homepage,
        salutation: anrede,
        letter_salutation: briefanr
      }
    end
  end
end
