require "rails_helper"

RSpec.describe ProcessLoggedSearchWorker, type: :job do
  let(:instance) { described_class.new }
  describe "perform" do
    context "user member of organization" do
      let!(:logged_search) { FactoryBot.create(:logged_search, user_id: user.id) }
      let(:user) { FactoryBot.create(:user_confirmed, :with_organization) }
      let(:organization) { user.reload.organizations.first }

      it "Process the logged_search" do
        expect(logged_search.user_id).to eq user.id
        expect(logged_search.organization_id).to be_nil
        expect(logged_search.processed?).to be_falsey

        instance.perform(logged_search.id)

        expect(logged_search.reload.processed?).to be_truthy
        expect(logged_search.organization_id).to eq organization.id
      end

      context 'user is superuser' do
        let(:user) { FactoryBot.create(:admin, :with_organization) }
        it "doesn't associate" do
          expect(logged_search.user_id).to eq user.id
          expect(logged_search.organization_id).to be_nil

          instance.perform(logged_search.id)

          expect(logged_search.reload.processed?).to be_truthy
          expect(logged_search.organization_id).to be_nil
        end
      end

      context 'organization_id is assigned' do
        before { logged_search.update(organization_id: 122) }
        it "doesn't update organization_id" do
          expect(logged_search.reload.processed?).to be_falsey

          instance.perform(logged_search.id)

          expect(logged_search.reload.processed?).to be_truthy
          expect(logged_search.organization_id).to eq 122
        end
      end
    end

    context 'ip_address' do
      let(:logged_search) { FactoryBot.create(:logged_search, ip_address: "181.41.206.24") }
      let!(:country) { Country.united_states }
      let!(:state) { FactoryBot.create(:state, abbreviation: "NY", name: "New York") }
      let(:target_location_attrs) do
        {
          latitude: 40.7143528,
          longitude: -74.0059731,
          neighborhood: "Tribeca",
          city: 'New York',
          zipcode: '10007',
          country_id: country.id,
          state_id: state.id
        }
      end
      it "geocodes ip address" do
        expect(logged_search.reload.latitude).to be_blank
        expect(logged_search.processed).to be_falsey

        instance.perform(logged_search.id)

        expect(logged_search.reload.processed?).to be_truthy
        expect_attrs_to_match_hash(logged_search, target_location_attrs)
      end

      context "maxmind response" do
        # require 'geocoder/results/base'

        # let(:max_mind_result) { [OpenStruct.new(data: geo_list, cache_hit=true] }
        # before { allow(Geocoder).to receive(:search).and_return(max_mind_result) }
      end
    end
  end
end
