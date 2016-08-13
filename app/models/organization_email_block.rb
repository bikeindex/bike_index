class OrganizationEmailBlock < ActiveRecord::Base
  belongs_to :organization
  validates_presence_of :block_type, :organization_id
  validates_uniqueness_of :block_type, scope: [:organization_id]

  class << self
    def block_types
      %w(header welcome security).freeze
    end
  end
end
