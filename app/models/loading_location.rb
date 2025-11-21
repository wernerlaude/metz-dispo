class LoadingLocation < ApplicationRecord
  self.primary_key = "id"  # Explizit setzen

  has_many :tours, dependent: :nullify
  validates :werk_name, presence: true

  scope :active, -> { where(active: true) }
  scope :inactive, -> { where(active: false) }
  scope :by_name, -> { order(:werk_name) }

  def to_s
    werk_name
  end

  def full_info
    info = [ werk_name ]
    info << address if address.present?
    info.join(", ")
  end
end
