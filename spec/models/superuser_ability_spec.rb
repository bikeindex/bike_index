# == Schema Information
#
# Table name: superuser_abilities
#
#  id              :bigint           not null, primary key
#  action_name     :string
#  controller_name :string
#  deleted_at      :datetime
#  kind            :integer          default("universal")
#  su_options      :jsonb
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  user_id         :bigint
#
# Indexes
#
#  index_superuser_abilities_on_user_id  (user_id)
#
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

  describe "can_access" do
    let(:superuser_ability) { FactoryBot.create(:superuser_ability) }
    let(:user) { superuser_ability.user }
    it "is accessible for universal" do
      expect(user.superuser_abilities.can_access?).to be_truthy
      expect(user.superuser_abilities.can_access?(controller_name: "bikes")).to be_truthy
      expect(user.superuser_abilities.can_access?(controller_name: "bikes", action_name: "edit")).to be_truthy
    end
    context "with controller_name: bikes" do
      let(:superuser_ability) { FactoryBot.create(:superuser_ability, controller_name: "bikes") }
      it "is correctly accessible" do
        expect(user.superuser_abilities.can_access?).to be_falsey
        expect(user.superuser_abilities.can_access?(controller_name: "bikes")).to be_truthy
        expect(user.superuser_abilities.can_access?(controller_name: "bikes", action_name: "show")).to be_truthy
        expect(user.superuser_abilities.can_access?(controller_name: "bikes", action_name: "edit")).to be_truthy
      end
    end
    context "with controller_name: bikes, action_name: edit" do
      let(:superuser_ability) { FactoryBot.create(:superuser_ability, controller_name: "bikes", action_name: "edit") }
      it "is correctly accessible" do
        user.reload
        expect(user.superuser_abilities.can_access?).to be_falsey
        expect(user.superuser_abilities.can_access?(controller_name: "bikes")).to be_falsey
        expect(user.superuser_abilities.can_access?(controller_name: "bikes", action_name: "show")).to be_truthy
        expect(user.superuser_abilities.can_access?(controller_name: "bikes", action_name: "edit")).to be_truthy
        expect(user.superuser_abilities.can_access?(controller_name: "bikes", action_name: "update")).to be_falsey
      end
    end
    context "with controller_name: bikes, action_name: show" do
      let(:superuser_ability) { FactoryBot.create(:superuser_ability, controller_name: "bikes", action_name: "show") }
      it "is correctly accessible" do
        expect(user.superuser_abilities.can_access?).to be_falsey
        expect(user.superuser_abilities.can_access?(controller_name: "bikes")).to be_falsey
        expect(user.superuser_abilities.can_access?(controller_name: "bikes", action_name: "show")).to be_truthy
        expect(user.superuser_abilities.can_access?(controller_name: "bikes", action_name: "edit")).to be_falsey
        expect(user.superuser_abilities.can_access?(controller_name: "bikes", action_name: "update")).to be_falsey
      end
    end
    context "with controller_name: graphs" do
      let(:superuser_ability) { FactoryBot.create(:superuser_ability, controller_name: "graphs") }
      it "is correctly accessible" do
        expect(user.superuser_abilities.can_access?).to be_falsey
        expect(user.superuser_abilities.can_access?(controller_name: "bikes")).to be_falsey
        expect(user.superuser_abilities.can_access?(controller_name: "bikes", action_name: "edit")).to be_falsey
      end
    end
  end
end
