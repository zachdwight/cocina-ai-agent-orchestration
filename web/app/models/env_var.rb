class EnvVar < ApplicationRecord
  belongs_to :agent
  validates :key, presence: true
end
