# app/models/vehicle.rb
class Vehicle < ApplicationRecord
  has_many :drivers, dependent: :nullify

  validates :license_plate, presence: true, uniqueness: true
  validates :vehicle_number, presence: true, uniqueness: true

  # Enums für vehicle_type
  enum :vehicle_type, {
    keine: 0,
    silozug: 1,
    silomasch: 2,
    silohang: 3,
    kipper: 4,
    kippmasch: 5,
    kipphang: 6,
    kipperlade: 7,
    sattelzug: 8,
    sackware: 9,
    fremdsack: 10,
    fremdkip: 11,
    fremdsilo: 12,
    fremdschub: 13,
    tankzug: 14,
    schubboden: 15
  }, prefix: true

  # Labels für Vehicle Types
  VEHICLE_TYPE_LABELS = {
    "keine" => "Keine Zuweisung",
    "silozug" => "Silo Zug",
    "silomasch" => "Silo Ma",
    "silohang" => "Silo Hä",
    "kipper" => "Kipper",
    "kippmasch" => "Kipper Ma",
    "kipphang" => "Kipper Hä",
    "kipperlade" => "Kipper La",
    "sattelzug" => "Sattelzug",
    "sackware" => "Sack Lkw",
    "fremdsack" => "Fremd Sack",
    "fremdkip" => "Fremd Kip",
    "fremdsilo" => "Fremd Silo",
    "fremdschub" => "Fremd Schub",
    "tankzug" => "Tank Zug",
    "schubboden" => "Schubb"
  }.freeze

  # Scopes
  scope :by_license_plate, -> { order(:license_plate) }

  # ============================================
  # Instanz-Methoden
  # ============================================

  def vehicle_type_label
    VEHICLE_TYPE_LABELS[vehicle_type] || vehicle_type
  end

  def vehicle_type_integer
    vehicle_type_before_type_cast
  end

  def vehicle_type_options_json
    self.class.vehicle_type_options_for_json.to_json
  end

  def display_name
    vehicle_short.present? ? "#{license_plate} (#{vehicle_short})" : license_plate
  end

  def to_s
    license_plate
  end

  # ============================================
  # Klassen-Methoden
  # ============================================

  # Für Anzeige in Tabellen: lkwnr -> "AN-AB 123 (Actros)"
  def self.display_name_for(lkwnr)
    return nil if lkwnr.blank?

    vehicle = find_by(vehicle_number: lkwnr)
    return lkwnr unless vehicle

    vehicle.display_name
  end

  # Für JSON in Inline-Edit Dropdowns
  def self.vehicle_type_options_for_json
    vehicle_types.keys.map { |type| { value: type, text: VEHICLE_TYPE_LABELS[type] } }
  end

  # Gibt das Typ-Label für einen Fahrzeugtyp zurück (String)
  # Beispiel: Vehicle.type_label_for("silozug") => "Silo Zug"
  def self.type_label_for(fahrzeug_type)
    return nil if fahrzeug_type.blank?
    VEHICLE_TYPE_LABELS[fahrzeug_type.to_s.downcase]
  end

  # Gibt das Typ-Label für eine Enum-Nummer zurück
  # Beispiel: Vehicle.type_label_for_number("1") => "Silo Zug"
  #           Vehicle.type_label_for_number("4") => "Kipper"
  def self.type_label_for_number(number)
    return nil if number.blank?

    # Enum-Key aus Nummer holen
    type_key = vehicle_types.key(number.to_i)
    return nil unless type_key

    VEHICLE_TYPE_LABELS[type_key]
  end

  # Kombinierte Anzeige: Kennzeichen wenn Fahrzeug existiert, sonst Typ-Label
  # Beispiel: Vehicle.display_for_lkwnr("3") => ["AN-MT 430 (Actros)", :success] (wenn Fahrzeug existiert)
  #           Vehicle.display_for_lkwnr("1") => ["Silo Zug", :success] (Typ-Label)
  #           Vehicle.display_for_lkwnr("0") => ["Keine Zuweisung", :warning]
  #           Vehicle.display_for_lkwnr(nil) => ["Nicht zugewiesen", :danger]
  def self.display_for_lkwnr(lkwnr)
    return [ "Nicht zugewiesen", :danger ] if lkwnr.blank?

    # 0 = Keine Zuweisung als warning
    return [ "Keine Zuweisung", :danger ] if lkwnr.to_s == "0"

    vehicle = find_by(vehicle_number: lkwnr)
    return [ vehicle.display_name, :success ] if vehicle

    type_label = type_label_for_number(lkwnr)
    return [ type_label, :success ] if type_label

    [ lkwnr.to_s, :danger ]
  end

  # Für Dropdowns im Modal (liefert Array von Hashes)
  def self.for_select
    order(:license_plate).pluck(:vehicle_number, :license_plate, :vehicle_short).map do |vn, lp, vs|
      { vehicle_number: vn, license_plate: lp, vehicle_short: vs }
    end
  end

  # Für Select-Optionen in Forms
  def self.vehicle_type_options_for_select
    vehicle_types.keys.map { |type| [ VEHICLE_TYPE_LABELS[type], type ] }
  end
end
