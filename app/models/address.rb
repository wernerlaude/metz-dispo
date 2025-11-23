# app/models/address.rb
class Address < ApplicationRecord
  if Rails.env.production?
    # Firebird in Production
    self.table_name = "adressen"
    self.primary_key = "nummer"

    # Firebird hat keine Timestamps
    self.record_timestamps = false
  else
    # PostgreSQL in Development
    self.table_name = "addresses_dev"
    self.primary_key = "id"
  end

  # Assoziationen
  belongs_to :customer,
             foreign_key: "knr",
             primary_key: "kundennr",
             optional: true

  has_many :address_restrictions, dependent: :destroy
  has_many :restricted_drivers, through: :address_restrictions, source: :driver

  # Validierungen
  validates :nummer, presence: true, uniqueness: true
  validates :name1, presence: true
  validates :plz, presence: true, format: { with: /\A\d{5}\z/, message: "muss 5-stellig sein" }
  validates :ort, presence: true
  validates :art, inclusion: { in: %w[KUNDE LIEFERANT SONSTIGE] }
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true

  # Scopes
  scope :customers, -> { where(art: "KUNDE") }
  scope :suppliers, -> { where(art: "LIEFERANT") }
  scope :by_city, ->(ort) { where(ort: ort) }
  scope :by_postal_code, ->(plz) { where(plz: plz) }

  # Helper Methoden
  def full_name
    [ name1, name2 ].compact.join(", ")
  end

  def full_address
    [
      name1,
      name2,
      strasse,
      "#{plz} #{ort}",
      land
    ].compact.reject(&:blank?).join(", ")
  end

  def short_address
    "#{strasse}, #{plz} #{ort}"
  end

  def customer?
    art == "KUNDE"
  end

  def supplier?
    art == "LIEFERANT"
  end
end
