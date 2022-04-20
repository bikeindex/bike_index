require 'rails_helper'

RSpec.describe SuperuserAbility, type: :model do
  let(:user) { FactoryBot.create(:user_confirmed) }
  describe "set_calculated_attributes" do
    let(:superuser_ability) { SuperuserAbility.create(user: user) }
    it "is based on access" do
      expect(superuser_ability.kind).to eq "universal"
      superuser_ability.update(controller_name: "graphs")
      expect(superuser_ability.reload.kind).to eq "controller"
      superuser_ability.update(action_name: "graphs")
      expect(superuser_ability.reload.kind).to eq "action"
    end
  end
end
