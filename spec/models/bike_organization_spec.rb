# == Schema Information
#
# Table name: bike_organizations
#
#  id                   :integer          not null, primary key
#  can_not_edit_claimed :boolean          default(FALSE), not null
#  deleted_at           :datetime
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  bike_id              :integer
#  organization_id      :integer
#
# Indexes
#
#  index_bike_organizations_on_bike_id          (bike_id)
#  index_bike_organizations_on_deleted_at       (deleted_at)
#  index_bike_organizations_on_organization_id  (organization_id)
#
require "rails_helper"

RSpec.describe BikeOrganization, type: :model do
  describe "can_edit_claimed" do
    let(:bike_organization) { BikeOrganization.new }
    it "assigns correctly" do
      expect(bike_organization.can_edit_claimed).to be_truthy
      bike_organization.can_edit_claimed = false
      expect(bike_organization.can_edit_claimed).to be_falsey
      expect(bike_organization.can_not_edit_claimed).to be_truthy
    end
  end
end
