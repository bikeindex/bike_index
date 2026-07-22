# frozen_string_literal: true

require "rails_helper"

RSpec.describe BikeServices::ShowViews do
  subject(:available_views) { described_class.available(bike:, current_user:, organization: nil) }
  let(:bike) { FactoryBot.create(:bike) }

  context "anonymous" do
    let(:current_user) { nil }
    it "is public only" do
      expect(available_views).to eq([[:public, nil]])
    end
  end

  context "owner" do
    let(:bike) { FactoryBot.create(:bike, :with_ownership_claimed) }
    let(:current_user) { bike.reload.user }
    it "includes owner and public" do
      expect(available_views).to eq([[:owner, nil], [:public, nil]])
    end
  end

  context "org member with bike edit" do
    let(:organization) { FactoryBot.create(:organization) }
    let(:current_user) { FactoryBot.create(:organization_admin, organization:) }
    it "includes the org staff view" do
      expect(available_views).to eq([[:staff, organization], [:public, nil]])
    end
  end

  context "org member without bike edit" do
    let(:organization) { FactoryBot.create(:organization) }
    let(:current_user) { FactoryBot.create(:organization_user, organization:, role: "member_no_bike_edit") }
    it "includes the org limited view" do
      expect(available_views).to eq([[:limited, organization], [:public, nil]])
    end
  end

  context "superuser" do
    let(:organization) { FactoryBot.create(:organization) }
    let(:bike) { FactoryBot.create(:bike_organized, creation_organization: organization) }
    let(:current_user) { FactoryBot.create(:superuser) }
    it "includes owner, both org roles, and public" do
      expect(available_views).to eq([[:owner, nil], [:staff, organization], [:limited, organization], [:public, nil]])
    end
  end

  describe ".permitted?" do
    let(:available_views) { [[:owner, nil], [:public, nil]] }

    it "is true for a view in available_views" do
      expect(described_class.permitted?([:owner, nil], available_views:)).to be(true)
    end

    it "is false for a view not in available_views" do
      expect(described_class.permitted?([:staff, FactoryBot.create(:organization)], available_views:)).to be(false)
    end

    it "is false for nil" do
      expect(described_class.permitted?(nil, available_views:)).to be(false)
    end
  end

  describe ".default_view_for" do
    subject(:default_view) { described_class.default_view_for(bike:, current_user:, passive_organization:) }
    let(:passive_organization) { nil }

    context "the bike's owner" do
      let(:bike) { FactoryBot.create(:bike, :with_ownership_claimed) }
      let(:current_user) { bike.reload.user }
      it { is_expected.to eq([:owner, nil]) }
    end

    context "anonymous" do
      let(:current_user) { nil }
      it { is_expected.to eq([:public, nil]) }
    end

    context "a passive organization the user is authorized for" do
      let(:organization) { FactoryBot.create(:organization) }
      let(:current_user) { FactoryBot.create(:organization_user, organization:, role: "member_no_bike_edit") }
      let(:passive_organization) { organization }
      it { is_expected.to eq([:limited, organization]) }
    end
  end
end
