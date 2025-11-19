class Tour < ApplicationRecord
  # Assoziationen
  has_many :delivery_positions, dependent: :nullify
  belongs_to :driver, optional: true
  belongs_to :loading_location, optional: true
  belongs_to :vehicle, optional: true  # NEU
  belongs_to :trailer, optional: true  # NEU

  # Validierungen
  validates :tour_date, presence: true
  validates :name, presence: true, uniqueness: { scope: :tour_date }

  # Scopes
  scope :today, -> { where(tour_date: Date.current) }
  scope :upcoming, -> { where("tour_date >= ?", Date.current) }
  scope :past, -> { where("tour_date < ?", Date.current) }
  scope :by_vehicle, ->(vehicle_id) { where(vehicle_id: vehicle_id) }
  scope :by_driver, ->(driver_id) { where(driver_id: driver_id) }
  scope :with_positions, -> { joins(:delivery_positions).distinct }
  scope :empty, -> { left_joins(:delivery_positions).where(delivery_positions: { id: nil }) }

  scope :filter_by, ->(filters) {
    tours = all

    tours = tours.where("name ILIKE ?", "%#{filters[:name]}%") if filters[:name].present?
    tours = tours.where(tour_date: filters[:tour_date]) if filters[:tour_date].present?
    tours = tours.where(driver_id: filters[:driver_id]) if filters[:driver_id].present?
    tours = tours.where(vehicle_id: filters[:vehicle_id]) if filters[:vehicle_id].present?
    tours = tours.where(trailer_id: filters[:trailer_id]) if filters[:trailer_id].present?
    tours = tours.where(completed: filters[:completed] == "true") if filters[:completed].present?

    tours
  }

  # Callbacks
  before_validation :set_default_name, on: :create

  # Helper Methoden
  def delivery_position_count
    delivery_positions.count
  end

  def customer_count
    delivery_positions.joins(:delivery).distinct.count("deliveries.kundennr")
  end

  def total_weight
    delivery_positions.sum(&:calculated_weight)
  end

  def ordered_positions
    delivery_positions.order(:sequence_number, :liefschnr, :posnr)
  end

  def has_positions?
    delivery_positions.exists?
  end

  def empty?
    !has_positions?
  end

  # Status basierend auf Positionen
  def status
    return :empty if empty?
    return :ready if has_positions?
    :unknown
  end

  # Alle Kunden in dieser Tour
  def customers
    delivery_positions.joins(:delivery)
                      .includes(delivery: :customer)
                      .map(&:delivery)
                      .map(&:customer)
                      .uniq
  end

  # Positionen gruppiert nach Kunde
  def positions_by_customer
    delivery_positions.includes(delivery: :customer)
                      .group_by { |pos| pos.delivery.customer }
  end

  # Tour-Informationen für Anzeige
  def summary
    {
      name: name,
      date: tour_date,
      vehicle: vehicle,
      driver: driver&.name,
      loading_location: loading_location&.name,
      positions: position_count,
      customers: customer_count,
      total_weight: "#{total_weight} kg",
      status: status
    }
  end

  # Neue Position hinzufügen
  def add_position!(delivery_position)
    return false if delivery_position.tour.present?

    next_sequence = delivery_positions.maximum(:sequence_number).to_i + 1
    delivery_position.update!(
      tour: self,
      sequence_number: next_sequence
    )
  end

  # Position entfernen
  def remove_position!(delivery_position)
    return false unless delivery_position.tour == self

    ActiveRecord::Base.transaction do
      old_sequence = delivery_position.sequence_number

      # WICHTIG: Entferne Position ZUERST
      delivery_position.update!(tour: nil, sequence_number: nil)

      # Renummeriere nur wenn sequence_number existierte
      if old_sequence
        # Hole alle Positionen die nach der entfernten Position kommen
        positions_to_update = delivery_positions
                                .where("sequence_number > ?", old_sequence)
                                .order(:sequence_number)
                                .to_a

        # Aktualisiere jede Position einzeln (vermeidet constraint violations)
        positions_to_update.each do |pos|
          pos.update_column(:sequence_number, pos.sequence_number - 1)
        end
      end
    end

    true
  end

  # Positionen neu ordnen
  def reorder_positions!(position_ids_in_order)
    transaction do
      position_ids_in_order.each_with_index do |position_id, index|
        delivery_positions.find(position_id)
                          .update!(sequence_number: index + 1)
      end
    end
  end

  private

  def set_default_name
    return if name.present?

    date_part = tour_date&.strftime("%d.%m") || Date.current.strftime("%d.%m")
    vehicle_part = vehicle || "Tour"

    self.name = "#{vehicle_part} #{date_part}"
  end
end
