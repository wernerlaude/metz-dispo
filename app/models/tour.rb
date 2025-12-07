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

  def default_loading_location_id
    return loading_location_id if loading_location_id.present?

    ladeort = delivery_items.first&.ladeort
    return nil unless ladeort.present?

    LoadingLocation.find_by(werk_name: ladeort)&.id
  end

  def items_datum
    delivery_items.where.not(datum: nil).minimum(:datum)
  end

  # Geplantes Lieferdatum aus den zugewiesenen Items (frühestes)
  def items_geplliefdatum
    delivery_items.where.not(geplliefdatum: nil).minimum(:geplliefdatum)
  end

  # app/models/tour.rb
  def dates_display
    dates = []
    dates << items_datum if items_datum.present?
    dates << items_geplliefdatum if items_geplliefdatum.present?
    dates
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

  # In app/models/tour.rb

  def liefadrnr_list
    delivery_items.pluck(:liefadrnr).compact.uniq
  end

  def drivers_for_select
    blocked_addresses = liefadrnr_list

    Driver.active.order(:last_name).map do |driver|
      # Prüfe ob Fahrer für eine der Adressen gesperrt ist
      is_blocked = blocked_addresses.any? &&
                   driver.address_restrictions.where(liefadrnr: blocked_addresses).exists?

      label = is_blocked ? "⚠️ #{driver.full_name} (gesperrt)" : driver.full_name
      [ label, driver.id ]
    end
  end

  # Effektives Fahrzeug (Tour oder aus Positionen)
  def effective_vehicle
    return vehicle if vehicle.present?

    # Fallback: lkwnr aus erster Position holen
    first_lkwnr = delivery_items.where.not(lkwnr: [nil, ""]).pick(:lkwnr)
    return nil unless first_lkwnr.present?

    Vehicle.find_by(vehicle_number: first_lkwnr)
  end

  def effective_vehicle_license_plate
    if vehicle.present?
      vehicle.license_plate
    else
      first_lkwnr = delivery_items.where.not(lkwnr: [nil, ""]).pick(:lkwnr)
      if first_lkwnr.present?
        found_vehicle = Vehicle.find_by(vehicle_number: first_lkwnr)
        found_vehicle&.license_plate || "LKW #{first_lkwnr}"
      else
        nil
      end
    end
  end

  # Effektiver Trailer (für Zukunft, falls trailer auch aus Positionen kommt)
  def effective_trailer_license_plate
    trailer&.license_plate
  end
end