require 'spec_helper'

describe Organization do
  describe 'validations' do
    # it { should validate_uniqueness_of :slug }
    it { is_expected.to validate_presence_of :name }
    it { is_expected.to have_many :memberships }
    it { is_expected.to have_many :organization_deals }
    it { is_expected.to have_many :users }
    it { is_expected.to have_many :organization_invitations }
    it { is_expected.to have_many :locations }
    it { is_expected.to have_many :bikes }
    it { is_expected.to belong_to :auto_user }
  end

  describe 'scopes' do
    it 'Shown on map is shown on map *and* validated' do
      expect(Organization.shown_on_map.to_sql).to eq(Organization.where(show_on_map: true).where(approved: true).order(:name).to_sql)
    end
  end

  describe 'set_and_clean_attributes' do
    it 'sets the short_name and the slug on save' do
      organization = Organization.new(name: 'something')
      organization.set_and_clean_attributes
      expect(organization.short_name).to be_present
      expect(organization.slug).to be_present
      slug = organization.slug
      organization.save
      expect(organization.slug).to eq(slug)
    end

    it "doesn't xss" do
      org = Organization.new(name: '<script>alert(document.cookie)</script>',
                             website: '<script>alert(document.cookie)</script>')
      org.set_and_clean_attributes
      expect(org.name).to eq('alert(document.cookie)')
      expect(org.website).to eq('http://<script>alert(document.cookie)</script>')
      expect(org.short_name).to eq('alert(document.cookie)')
    end

    it "protects from name collisions, without erroring because of it's own slug" do
      org1 = Organization.create(name: 'Bicycle shop')
      org1.reload.save
      expect(org1.reload.slug).to eq('bicycle-shop')
      organization = Organization.new(name: 'Bicycle shop')
      organization.set_and_clean_attributes
      expect(organization.slug).to eq('bicycle-shop-2')
    end

    it 'has before_save_callback_method defined for set_and_clean_attributes' do
      expect(Organization._save_callbacks.select { |cb| cb.kind.eql?(:before) }.map(&:raw_filter).include?(:set_and_clean_attributes)).to eq(true)
    end
  end

  describe 'set_locations_shown' do
    let(:country) { FactoryGirl.create(:country) }
    let(:organization) { FactoryGirl.create(:organization, show_on_map: true) }
    let(:location) { Location.create(country_id: country.id, city: 'Chicago', name: 'stuff', organization_id: organization.id, shown: true) }
    context 'organization approved' do
      before do
        organization.update_attribute :approved, true
        organization.reload
      end
      it 'sets the locations shown to be org shown on save' do
        expect(organization.allowed_show).to be_truthy
        organization.set_locations_shown
        expect(location.reload.shown).to be_truthy
      end
    end
    context 'not approved' do
      it 'sets not shown' do
        expect(organization.show_on_map).to be_truthy
        organization.set_locations_shown
        expect(location.reload.shown).to be_falsey
      end
    end
    it 'has before_save_callback_method defined for set_locations_shown' do
      expect(Organization._save_callbacks.select { |cb| cb.kind.eql?(:before) }.map(&:raw_filter).include?(:set_locations_shown)).to eq(true)
    end
  end

  describe 'set_auto_user' do
    it 'sets the embedable user' do
      organization = FactoryGirl.create(:organization)
      user = FactoryGirl.create(:user, email: 'embed@org.com')
      membership = FactoryGirl.create(:membership, organization: organization, user: user)
      organization.embedable_user_email = 'embed@org.com'
      organization.save
      expect(organization.reload.auto_user_id).to eq(user.id)
    end
    it 'does not set the embedable user if user is not a member' do
      organization = FactoryGirl.create(:organization)
      user = FactoryGirl.create(:user, email: 'no_embed@org.com')
      organization.embedable_user_email = 'no_embed@org.com'
      organization.save
      expect(organization.reload.auto_user_id).to be_nil
    end
    it 'Makes a membership if the user is auto user' do
      organization = FactoryGirl.create(:organization)
      user = FactoryGirl.create(:user, email: ENV['AUTO_ORG_MEMBER'])
      organization.embedable_user_email = ENV['AUTO_ORG_MEMBER']
      organization.save
      expect(organization.reload.auto_user_id).to eq(user.id)
    end
    it "sets the embedable user if it isn't set and the org has members" do
      organization = FactoryGirl.create(:organization)
      user = FactoryGirl.create(:user)
      membership = FactoryGirl.create(:membership, user: user, organization: organization)
      organization.save
      expect(organization.reload.auto_user_id).not_to be_nil
    end
  end

  describe 'clear_map_cache' do
    it 'has before_save_callback_method defined for clear clear_map_cache' do
      expect(Organization._save_callbacks.select { |cb| cb.kind.eql?(:after) }.map(&:raw_filter).include?(:clear_map_cache)).to eq(true)
    end
  end
end
