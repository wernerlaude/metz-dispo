class LoadingLocation < ApplicationRecord
  has_many :tours, dependent: :nullify

  validates :name, presence: true

  scope :active, -> { where(active: true) }
  scope :inactive, -> { where(active: false) }
  scope :by_name, -> { order(:name) }

  def to_s
    name
  end

  def full_info
    info = [ name ]
    info << address if address.present?
    info.join(", ")
  end
end
