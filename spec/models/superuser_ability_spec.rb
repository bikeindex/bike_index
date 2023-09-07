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

  describe "su_options" do
    let(:user1) { FactoryBot.create(:user) }
    let!(:superuser_ability1) { SuperuserAbility.create(user: user1) }
    let(:user2) { FactoryBot.create(:user) }
    let!(:superuser_ability2) { SuperuserAbility.create(user: user2, su_options: [:no_always_show_credibility, :no_hide_spam]) }
    it "returns matches" do
      user1.reload
      user2.reload
      expect(SuperuserAbility.su_inverse_option?(:no_hide_spam)).to be_falsey
      expect(SuperuserAbility.su_inverse_option("no_hide_spam")).to be_nil
      expect(SuperuserAbility.su_inverse_option?(:hide_spam)).to be_truthy
      expect(SuperuserAbility.su_inverse_option("hide_spam")).to eq :no_hide_spam
      expect(superuser_ability1.su_option?(:no_hide_spam)).to be_falsey
      expect(superuser_ability1.su_option?(:hide_spam)).to be_truthy
      expect(superuser_ability1.su_option?(:no_always_show_credibility)).to be_falsey
      expect(superuser_ability1.su_option?(:always_show_credibility)).to be_truthy

      expect(superuser_ability2.su_option?("no_hide_spam")).to be_truthy
      expect(superuser_ability2.su_option?("hide_spam")).to be_falsey
      expect(superuser_ability2.su_option?("no_always_show_credibility")).to be_truthy
      expect(superuser_ability2.su_option?("always_show_credibility")).to be_falsey

      expect(SuperuserAbility.with_su_option("no_always_show_credibility").pluck(:id)).to eq([superuser_ability2.id])
      expect(SuperuserAbility.with_su_option("always_show_credibility").pluck(:id)).to eq([superuser_ability1.id])
      expect(user1.su_option?(:no_always_show_credibility)).to be_falsey
      expect(user2.su_option?(:no_always_show_credibility)).to be_truthy
      expect(SuperuserAbility.with_su_option("no_hide_spam").pluck(:id)).to eq([superuser_ability2.id])
      expect(SuperuserAbility.with_su_option("hide_spam").pluck(:id)).to eq([superuser_ability1.id])
      expect(user1.su_option?(:hide_spam)).to be_truthy
      expect(user2.su_option?(:hide_spam)).to be_falsey
    end
  end
end


