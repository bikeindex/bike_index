class OrganizationDeal < ActiveRecord::Base
  def self.old_attr_accessible
    %w(organization_id deal_name email user_id).map(&:to_sym).freeze
  end

  belongs_to :organization
  belongs_to :user 

  validates_presence_of :organization_id, :deal_name, :email
  


end
