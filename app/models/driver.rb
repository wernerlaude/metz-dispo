class Driver < ApplicationRecord
  belongs_to :vehicle, optional: true
  belongs_to :trailer, optional: true
  has_many :tours, dependent: :nullify
  has_many :address_restrictions, dependent: :destroy

  # Validations
  validates :first_name, presence: true, length: { maximum: 45 }
  validates :last_name, presence: true, length: { maximum: 45 }
  validates :pin, presence: true, uniqueness: true, length: { maximum: 45 }

  # Enums - Rails 8 Syntax
  enum :driver_type, {
    regular: 0,
    external: 1,
    subcontractor: 2
  }, prefix: true

  # Scopes
  scope :active, -> { where(active: true) }
  scope :inactive, -> { where(active: false) }
  scope :regular_drivers, -> { where(driver_type: 0) }
  scope :sortiert, -> { order(:last_name) }

  # Labels für Driver Types
  DRIVER_TYPE_LABELS = {
    "regular" => "Regular",
    "external" => "Extern",
    "subcontractor" => "Subunternehmer"
  }.freeze

  def driver_type_label
    DRIVER_TYPE_LABELS[driver_type] || driver_type
  end

  # Für Select-Optionen in Forms
  def self.driver_type_options_for_select
    driver_types.keys.map { |type| [ DRIVER_TYPE_LABELS[type], type ] }
  end

  # Helper für gesperrte Adressen
  def blocked_liefadrnr_list
    address_restrictions.pluck(:liefadrnr)
  end

  # Hilfsmethoden
  def full_name
    "#{first_name} #{last_name}"
  end

  def name_with_type
    type_suffix = driver_type == "regular" ? "" : " (#{driver_type_label})"
    "#{full_name}#{type_suffix}"
  end

  def to_s
    full_name
  end
end
