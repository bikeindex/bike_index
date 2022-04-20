require "rails_helper"

RSpec.describe SuperuserAbility, type: :model do
  let(:user) { FactoryBot.create(:user_confirmed) }
  describe "set_calculated_attributes" do
    let(:superuser_ability) { SuperuserAbility.create(user: user) }
    it "is based on access" do
      expect(superuser_ability.kind).to eq "universal"
      expect(user.reload.superuser_abilities.can_access?(controller_name: "bikes")).to be_truthy
      superuser_ability.update(controller_name: "graphs")
      expect(user.reload.superuser_abilities.can_access?(controller_name: "bikes")).to be_falsey
      expect(user.superuser_abilities.can_access?(controller_name: "graphs")).to be_truthy
      expect(superuser_ability.reload.kind).to eq "controller"
      superuser_ability.update(action_name: "tables")
      expect(superuser_ability.reload.kind).to eq "action"
      expect(user.reload.superuser_abilities.can_access?(controller_name: "graphs")).to be_falsey
      expect(user.superuser_abilities.can_access?(controller_name: "graphs", action_name: "tables")).to be_truthy
    end
  end
end
