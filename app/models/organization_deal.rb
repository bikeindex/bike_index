class OrganizationDeal < ActiveRecord::Base
  attr_accessible :organization_id, :deal_name, :email, :user_id

  belongs_to :organization
  belongs_to :user 

  validates_presence_of :organization_id, :deal_name, :email
  


end
