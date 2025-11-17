class Driver < ApplicationRecord
  has_many :tours, dependent: :nullify

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

  # Hilfsmethoden
  def full_name
    "#{first_name} #{last_name}"
  end

  def name_with_type
    type_label = case driver_type
    when "regular" then ""
    when "external" then " (Extern)"
    when "subcontractor" then " (Subunternehmer)"
    end
    "#{full_name}#{type_label}"
  end

  def to_s
    full_name
  end
end
