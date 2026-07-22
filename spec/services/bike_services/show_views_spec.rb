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

    context "with a requested_view for an unrelated organization" do
      let(:bike) { FactoryBot.create(:bike) }
      let(:requested_organization) { FactoryBot.create(:organization) }
      subject(:available_views) do
        described_class.available(bike:, current_user:, organization: nil, requested_view: [:staff, requested_organization])
      end
      it "previews both roles of the requested organization" do
        expect(available_views).to eq([[:owner, nil],
          [:staff, requested_organization], [:limited, requested_organization], [:public, nil]])
      end
    end
  end

  context "non-superuser with a requested_view they aren't a member of" do
    let(:organization) { FactoryBot.create(:organization) }
    let(:current_user) { FactoryBot.create(:user_confirmed) }
    subject(:available_views) do
      described_class.available(bike:, current_user:, organization: nil, requested_view: [:staff, organization])
    end
    it "ignores the requested organization" do
      expect(available_views).to eq([[:public, nil]])
    end
  end

  describe ".default_view_for" do
    subject(:default_view) { described_class.default_view_for(bike:, current_user:, organization:) }
    let(:organization) { nil }

    context "the bike's owner" do
      let(:bike) { FactoryBot.create(:bike, :with_ownership_claimed) }
      let(:current_user) { bike.reload.user }
      it { is_expected.to eq([:owner, nil]) }
    end

    context "anonymous" do
      let(:current_user) { nil }
      it { is_expected.to eq([:public, nil]) }
    end

    context "an organization the user is authorized for" do
      let(:organization) { FactoryBot.create(:organization) }
      let(:current_user) { FactoryBot.create(:organization_user, organization:, role: "member_no_bike_edit") }
      it { is_expected.to eq([:limited, organization]) }
    end
  end
end
