require 'spec_helper'

describe Organization do
  describe 'validations' do
    # it { should validate_uniqueness_of :slug }
    it { is_expected.to validate_presence_of :name }
    it { is_expected.to have_many :memberships }
    it { is_expected.to have_many :mail_snippets }
    it { is_expected.to have_many :users }
    it { is_expected.to have_many :organization_invitations }
    it { is_expected.to have_many(:bike_organizations) }
    # it { is_expected.to have_many(:bikes).through(:bike_organizations) }
    it { is_expected.to have_many :creation_states }
    it { is_expected.to have_many(:created_bikes).through(:creation_states) }

    it { is_expected.to have_many :locations }
    it { is_expected.to belong_to :auto_user }
  end

  describe 'scopes' do
    it 'Shown on map is shown on map *and* validated' do
      expect(Organization.shown_on_map.to_sql).to eq(Organization.where(show_on_map: true).where(approved: true).order(:name).to_sql)
    end
  end

  describe 'admin text search' do
    context 'by name' do
      let!(:organization) { FactoryGirl.create(:organization, name: 'University of Maryland') }
      it 'finds the organization' do
        expect(Organization.admin_text_search('maryl')).to eq([organization])
      end
    end
    context 'by slug' do
      let!(:organization) { FactoryGirl.create(:organization, short_name: 'UMD') }
      it 'finds the organization' do
        expect(Organization.admin_text_search('umd')).to eq([organization])
      end
    end
    context 'through locations' do
      let!(:organization) { location.organization }
      context 'by location name' do
        let(:location) { FactoryGirl.create(:location, name: 'Sweet spot') }
        it 'finds the organization' do
          expect(Organization.admin_text_search('sweet Spot')).to eq([organization])
        end
      end
      context 'by location city' do
        let(:location) { FactoryGirl.create(:location, city: 'Chicago') }
        let!(:location_2) { FactoryGirl.create(:location, city: 'Chicago', organization: organization) }
        it 'finds the organization' do
          expect(Organization.admin_text_search('chi')).to eq([organization])
        end
      end
    end
  end

  describe "is_paid and paid_for? calculations" do
    let(:paid_feature) { FactoryGirl.create(:paid_feature, amount_cents: 10_000, name: "CSV Exports") }
    let(:invoice) { FactoryGirl.create(:invoice_paid, amount_due: 0) }
    let(:organization) { invoice.organization }
    let(:organization_child) { FactoryGirl.create(:organization) }
    it "uses associations to determine is_paid" do
      expect(organization.paid_for?("csv-exports")).to be_falsey
      invoice.update_attributes(paid_feature_ids: [paid_feature.id])
      organization.update_attributes(updated_at: Time.now) # TODO: Rails 5 update - after_commit
      expect(organization.is_paid).to be_truthy
      expect(organization.paid_feature_slugs).to eq([paid_feature.slug])
      expect(organization.paid_for?("csv-exports")).to be_truthy
      organization_child.update_attributes(updated_at: Time.now) # TODO: Rails 5 update - after_commit
      expect(organization_child.is_paid).to be_falsey
      organization_child.update_attributes(parent_organization: organization)
      expect(organization_child.is_paid).to be_truthy
      expect(organization_child.current_invoice).to eq invoice
      expect(organization_child.paid_feature_slugs).to eq([paid_feature.slug])
      expect(organization_child.paid_for?("CSV Exports")).to be_truthy # It also checks for the full name version
      expect(organization.child_organizations.pluck(:id)).to eq([organization_child.id])
    end
  end

  describe 'organization recoveries' do
    let(:organization) { FactoryGirl.create(:organization) }
    let(:bike) { FactoryGirl.create(:stolen_bike, creation_organization_id: organization.id) }
    let(:stolen_record) { bike.find_current_stolen_record }
    let!(:bike_organization) { FactoryGirl.create(:bike_organization, bike: bike, organization: organization) }
    let(:recovery_information) do
      {
        recovered_description: 'recovered it on a special corner',
        index_helped_recovery: true,
        can_share_recovery: true
      }
    end
    it 'returns recovered bikes' do
      organization.reload
      expect(organization.bikes).to eq([bike])
      expect(organization.bikes.stolen).to eq([bike])
      stolen_record.add_recovery_information(recovery_information)
      bike.reload
      expect(bike.stolen_recovery?).to be_truthy
      expect(organization.recovered_records).to eq([stolen_record])
    end
  end

  describe 'set_calculated_attributes' do
    it 'sets the short_name and the slug on save' do
      organization = Organization.new(name: 'something')
      organization.set_calculated_attributes
      expect(organization.short_name).to be_present
      expect(organization.slug).to be_present
      slug = organization.slug
      organization.save
      expect(organization.slug).to eq(slug)
    end

    it "doesn't xss" do
      org = Organization.new(name: '<script>alert(document.cookie)</script>',
                             website: '<script>alert(document.cookie)</script>')
      org.set_calculated_attributes
      expect(org.name).to match(/stop messing about/i)
      expect(org.website).to eq('http://<script>alert(document.cookie)</script>')
      expect(org.short_name).to match(/stop messing about/i)
    end

    it "protects from name collisions, without erroring because of it's own slug" do
      org1 = Organization.create(name: 'Bicycle shop')
      org1.reload.save
      expect(org1.reload.slug).to eq('bicycle-shop')
      organization = Organization.new(name: 'Bicycle shop')
      organization.set_calculated_attributes
      expect(organization.slug).to eq('bicycle-shop-2')
    end
    describe 'set_locations_shown' do
      let(:country) { FactoryGirl.create(:country) }
      let(:organization) { FactoryGirl.create(:organization, show_on_map: true, approved: true) }
      let(:location) { Location.create(country_id: country.id, city: 'Chicago', name: 'stuff', organization_id: organization.id, shown: true) }
      context 'organization approved' do
        it 'sets the locations shown to be org shown on save' do
          expect(organization.allowed_show).to be_truthy
          organization.set_calculated_attributes
          expect(location.reload.shown).to be_truthy
        end
      end
      context 'not approved' do
        it 'sets not shown' do
          organization.update_attribute :approved, false
          organization.reload
          expect(organization.allowed_show).to be_falsey
          organization.set_calculated_attributes
          expect(location.reload.shown).to be_falsey
        end
      end
    end

    describe 'set_auto_user' do
      it 'sets the embedable user' do
        organization = FactoryGirl.create(:organization)
        user = FactoryGirl.create(:confirmed_user, email: 'embed@org.com')
        FactoryGirl.create(:membership, organization: organization, user: user)
        organization.embedable_user_email = 'embed@org.com'
        organization.save
        expect(organization.reload.auto_user_id).to eq(user.id)
      end
      it 'does not set the embedable user if user is not a member' do
        organization = FactoryGirl.create(:organization)
        FactoryGirl.create(:confirmed_user, email: 'no_embed@org.com')
        organization.embedable_user_email = 'no_embed@org.com'
        organization.save
        expect(organization.reload.auto_user_id).to be_nil
      end
      it 'Makes a membership if the user is auto user' do
        organization = FactoryGirl.create(:organization)
        user = FactoryGirl.create(:confirmed_user, email: ENV['AUTO_ORG_MEMBER'])
        organization.embedable_user_email = ENV['AUTO_ORG_MEMBER']
        organization.save
        expect(organization.reload.auto_user_id).to eq(user.id)
      end
      it "sets the embedable user if it isn't set and the org has members" do
        organization = FactoryGirl.create(:organization)
        user = FactoryGirl.create(:confirmed_user)
        FactoryGirl.create(:membership, user: user, organization: organization)
        organization.save
        expect(organization.reload.auto_user_id).not_to be_nil
      end
    end
  end

  describe 'ensure_auto_user' do
    let(:organization) { FactoryGirl.create(:organization) }
    context 'existing members' do
      let(:member) { FactoryGirl.create(:organization_member, organization: organization) }
      before do
        expect(member).to be_present
      end
      it 'sets the first user' do
        organization.ensure_auto_user
        organization.reload
        expect(organization.auto_user).to eq member
      end
    end
    context 'no members' do
      let(:auto_user) { FactoryGirl.create(:confirmed_user, email: ENV['AUTO_ORG_MEMBER']) }
      before do
        expect(organization).to be_present
        expect(auto_user).to be_present
      end
      it 'sets the AUTO_ORG_MEMBER' do
        organization.ensure_auto_user
        organization.reload
        expect(organization.auto_user).to eq auto_user
      end
    end
  end

  describe 'display_avatar' do
    context 'unpaid' do
      it 'does not display' do
        organization = Organization.new(is_paid: false)
        allow(organization).to receive(:avatar) { 'a pretty picture' }
        expect(organization.display_avatar).to be_falsey
      end
    end
    context 'paid' do
      it 'displays' do
        organization = Organization.new(is_paid: true)
        allow(organization).to receive(:avatar) { 'a pretty picture' }
        expect(organization.display_avatar).to be_truthy
      end
    end
  end

  describe 'mail_snippet_body' do
    let(:organization) { FactoryGirl.create(:organization) }
    before do
      expect([organization, mail_snippet].size).to eq 2
      expect(organization.mail_snippets).to be_present
    end
    context 'not included snippet type' do
      let(:mail_snippet) { FactoryGirl.create(:organization_mail_snippet, organization: organization, name: 'fool') }
      it 'returns nil for not-allowed snippet type' do
        expect(organization.mail_snippet_body('fool')).to be nil
      end
    end
    context 'non-enabled snippet type' do
      let(:mail_snippet) { FactoryGirl.create(:organization_mail_snippet, organization: organization, is_enabled: false) }
      it 'returns nil for not-enabled snippet' do
        expect(organization.mail_snippet_body(mail_snippet.name)).to be nil
      end
    end
    context 'enabled snippet' do
      let(:mail_snippet) { FactoryGirl.create(:organization_mail_snippet, organization: organization, name: 'security') }
      it 'returns nil for not-enabled snippet' do
        expect(organization.mail_snippet_body(mail_snippet.name)).to eq mail_snippet.body
      end
    end
  end

  describe "organization_message_kinds" do
    let(:organization) { FactoryGirl.create(:organization) }
    let!(:mail_snippet) { FactoryGirl.create(:mail_snippet, organization: organization, name: "abandoned_bike") }
    let!(:user) { FactoryGirl.create(:organization_member, organization: organization) }
    it "returns empty for non-geolocated_emails" do
      expect(organization.organization_message_kinds).to eq([])
      expect(organization.permitted_message_kind?(nil)).to be_falsey
      expect(mail_snippet).to be_present
      expect(user.bike_actions_organization_id).to eq nil
      organization.update_attributes(geolocated_emails: true, abandoned_bike_emails: true)
      expect(organization.organization_message_kinds).to match_array(%w[geolocated abandoned_bike])
      expect(organization.permitted_message_kind?("abandoned_bike")).to be_truthy
      # TODO: Rails 5 update - Have to manually deal with updating because rspec doesn't correctly manage after_commit
      user.update_attributes(updated_at: Time.now)
      expect(user.bike_actions_organization_id).to eq organization.id
    end
  end
end
