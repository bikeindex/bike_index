# == Schema Information
#
# Table name: cgroups
#
#  id          :integer          not null, primary key
#  description :string(255)
#  name        :string(255)
#  priority    :integer          default(1)
#  slug        :string(255)
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
require "rails_helper"

RSpec.describe Cgroup, type: :model do
  it_behaves_like "friendly_slug_findable"

  describe "additional_parts" do
    it "finds additional parts" do
      expect(Cgroup.additional_parts.name).to eq "Additional parts"
    end
  end

  describe "bike_attributable scopes" do
    let(:component_1) { FactoryBot.create(:component) }
    let!(:ctype_1) { component_1.ctype }
    let(:bike) { component_1.bike }
    let!(:component_1_again) { FactoryBot.create(:component, ctype: ctype_1, bike:) }
    let(:component_2) { FactoryBot.create(:component, bike:) }
    let!(:ctype_2) { component_2.ctype }
    it "finds them correctly" do
      expect(bike.reload.components.pluck(:id)).to match_array([component_1.id, component_1_again.id, component_2.id])
      expect(bike.ctypes.pluck(:id)).to match_array([ctype_1.id, ctype_2.id])
      expect(bike.cgroups.pluck(:id)).to match_array([ctype_1.cgroup_id, ctype_2.cgroup_id])
      # TODO: Figure out how to order this without unscoping :/
      expect(bike.cgroups.unscoped.commonness.pluck(:id)).to eq(Cgroup.commonness.pluck(:id))
    end
  end
end
