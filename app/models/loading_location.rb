class LoadingLocation < ApplicationRecord
  has_many :tours, dependent: :nullify

  validates :name, presence: true

  scope :active, -> { where(active: true) }
  scope :by_name, -> { order(:name) }
end
