# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Admin::Users::Summary::Component, type: :component do
  let(:user) { FactoryBot.create(:user_confirmed) }
  let(:component) { render_inline(described_class.new(user:)) }

  it "renders no superuser info" do
    expect(component).to_not have_content("full superuser")
  end

  context "with superuser" do
    let(:user) { FactoryBot.create(:superuser) }
    let!(:superuser_ability) { SuperuserAbility.create(user:) }

    it "renders superuser info" do
      expect(component).to have_content("full superuser")
    end
  end
end
