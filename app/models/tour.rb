# app/models/tour.rb
class Tour < ApplicationRecord
  # Associations
  belongs_to :driver, optional: true
  belongs_to :vehicle, optional: true
  belongs_to :trailer, optional: true
  belongs_to :loading_location, optional: true

  # NEU: delivery_items statt delivery_positions
  has_many :delivery_items,
           class_name: "UnassignedDeliveryItem",
           dependent: :nullify

  # Alias für Kompatibilität (falls alter Code delivery_positions nutzt)
  alias_method :delivery_positions, :delivery_items

  # Validierungen
  validates :name, presence: true

  # Scopes
  scope :active, -> { where(completed: false) }
  scope :completed, -> { where(completed: true) }
  scope :today, -> { where(tour_date: Date.current) }
  scope :filter_by, ->(params) {
    result = all
    result = result.where(driver_id: params[:driver_id]) if params[:driver_id].present?
    result = result.where(vehicle_id: params[:vehicle_id]) if params[:vehicle_id].present?
    result = result.where(trailer_id: params[:trailer_id]) if params[:trailer_id].present?
    result = result.where(completed: params[:completed]) if params[:completed].present?
    result = result.where(tour_date: params[:tour_date]) if params[:tour_date].present?
    result
  }

  # Helper
  def total_weight
    delivery_items.sum { |item| item.calculated_weight.to_f }
  end

  def total_positions
    delivery_items.count
  end

  # Kompatibilität mit alten Views
  def delivery_position_count
    delivery_items.count
  end

  def has_positions?
    delivery_items.any?
  end

  def ordered_positions
    delivery_items.order(:sequence_number, :liefschnr, :posnr)
  end
end
