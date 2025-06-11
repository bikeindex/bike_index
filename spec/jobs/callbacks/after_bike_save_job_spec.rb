require "rails_helper"

RSpec.describe Callbacks::AfterBikeSaveJob, type: :job do
  let(:instance) { described_class.new }
  before { Sidekiq::Job.clear_all }

  it "is the correct queue" do
    expect(described_class.sidekiq_options["queue"]).to eq "low_priority"
  end

  describe "enqueuing jobs" do
    let(:bike_id) { FactoryBot.create(:ownership, user_hidden: true).bike_id }
    it "enqueues the duplicate_bike_finder_worker" do
      expect {
        instance.perform(bike_id)
      }.to change(DuplicateBikeFinderJob.jobs, :size).by 1
    end
  end

  it "doesn't break if unable to find bike" do
    instance.perform(96)
  end

  describe "update listing order and credibility score" do
    let(:bike) { FactoryBot.create(:bike) }

    it "updates the listing order" do
      bike.update_attribute :listing_order, -22
      instance.perform(bike.id)
      bike.reload
      expect(bike.listing_order).to eq bike.calculated_listing_order
      expect(bike.credibility_score).to eq 50
    end

    context "unchanged listing order" do
      it "does not update the listing order or enqueue afterbikesave" do
        bike.update_attribute :listing_order, bike.calculated_listing_order
        expect_any_instance_of(Bike).to_not receive(:update_attribute)
        instance.perform(bike.id)
      end
    end

    context "with marketplace_listing" do
      let!(:marketplace_listing) { FactoryBot.create(:marketplace_listing, item: bike) }

      it "updates the marketplace_listing updated_at" do
        marketplace_listing.update_column :updated_at, Time.current - 1.hour
        expect(marketplace_listing.reload.updated_at).to be < Time.current - 50.minutes
        instance.perform(bike.id)
        expect(marketplace_listing.reload.updated_at).to be_within(1).of Time.current
      end
    end
  end

  describe "download external_image_urls" do
    let(:external_image_urls) { ["https://files.bikeindex.org/email_assets/logo.png", "https://files.bikeindex.org/email_assets/logo.png", "https://files.bikeindex.org/email_assets/bike_photo_placeholder.png"] }
    let(:passed_external_image_urls) { external_image_urls }
    let(:bike) { FactoryBot.create(:bike) }
    let!(:b_param) do
      FactoryBot.create(:b_param,
        created_bike_id: bike.id,
        params: {bike: {owner_email: bike.owner_email, external_image_urls: passed_external_image_urls}})
    end
    it "creates and downloads the images" do
      expect {
        instance.perform(bike.id)
      }.to change(PublicImage, :count).by 2
      bike.reload
      # The public images have been created with the matching urls
      expect(bike.public_images.pluck(:external_image_url)).to match_array external_image_urls.uniq
      # Processing occurs in the processing job - not inline
      expect(bike.public_images.any? { |i| i.image.present? }).to be_falsey
      expect(Images::ExternalUrlStoreJob.jobs.count).to eq 2
    end
    context "images already exist, passed some blank values" do
      let(:passed_external_image_urls) { external_image_urls + [nil, ""] }
      it "doesn't create new images" do
        external_image_urls.uniq.each { |url| bike.public_images.create(external_image_url: url) }
        bike.reload
        expect(bike.external_image_urls).to eq external_image_urls.uniq
        expect {
          instance.perform(bike.id)
        }.to_not change(PublicImage, :count)
        bike.reload
      end
    end
  end

  describe "create_user_registration_organizations" do
    let(:bike) { FactoryBot.create(:bike_organized, :with_ownership) }
    let(:ownership) { bike.current_ownership }
    it "doesn't create" do
      expect(bike.reload.user&.id).to be_blank
      expect(bike.bike_organizations.count).to eq 1
      expect(bike.ownerships.pluck(:id)).to eq([ownership.id])
      expect(UserRegistrationOrganization.unscoped.count).to eq 0
      Sidekiq::Job.clear_all
      instance.perform(bike.id)
      expect(Sidekiq::Job.jobs.count).to eq 1
      expect(Sidekiq::Job.jobs.count { |j| j["class"] != "DuplicateBikeFinderJob" }).to eq 0
      expect(UserRegistrationOrganization.unscoped.count).to eq 0
      expect(bike.reload.bike_organizations.count).to eq 1
      expect(bike.ownerships.pluck(:id)).to eq([ownership.id])
    end
    context "with ownership claimed" do
      let(:bike) { FactoryBot.create(:bike, :with_ownership_claimed, creation_organization: organization) }
      let(:organization) { FactoryBot.create(:organization) }
      let(:user) { bike.user }
      let(:bike_organization) { bike.bike_organizations.first }
      it "creates" do
        expect(bike.reload.user&.id).to be_present
        expect(bike_organization.organization_id).to eq organization.id
        expect(bike.ownerships.pluck(:id)).to eq([ownership.id])
        expect(ownership.registration_info).to eq({})
        expect(UserRegistrationOrganization.unscoped.count).to eq 0
        expect(user.user_registration_organizations.count).to eq 0
        Sidekiq::Job.clear_all
        instance.perform(bike.id)
        expect(Sidekiq::Job.jobs.map { |j| j["class"] }.sort).to eq(%w[DuplicateBikeFinderJob])
        expect(bike.reload.bike_organizations.pluck(:organization_id)).to eq([organization.id])
        expect(bike.ownerships.pluck(:id)).to eq([ownership.id])
        expect(UserRegistrationOrganization.unscoped.count).to eq 1
        expect(user.reload.user_registration_organizations.count).to eq 1
        expect(ownership.reload.registration_info).to eq({})
        expect(ownership.overridden_by_user_registration?).to be_falsey
        user_registration_organization = user.reload.user_registration_organizations.first
        expect(user_registration_organization.organization_id).to eq organization.id
        expect(user_registration_organization.all_bikes).to be_falsey
        expect(user_registration_organization.registration_info).to be_blank
        expect(user_registration_organization.bikes.pluck(:id)).to eq([bike.id])
        expect(bike_organization.reload.organization_id).to eq organization.id
        expect(bike_organization.overridden_by_user_registration?).to be_falsey
      end
      context "deleted organization" do
        it "doesn't create" do
          expect(bike.reload.user&.id).to be_present
          expect(bike.bike_organizations.count).to eq 1
          organization.destroy
          expect(bike.ownerships.pluck(:id)).to eq([ownership.id])
          expect(UserRegistrationOrganization.unscoped.count).to eq 0
          Sidekiq::Job.clear_all
          instance.perform(bike.id)
          expect(Sidekiq::Job.jobs.map { |j| j["class"] }.sort).to eq(%w[DuplicateBikeFinderJob])
          expect(UserRegistrationOrganization.unscoped.count).to eq 0
          expect(bike.reload.bike_organizations.count).to eq 1
          expect(bike.ownerships.pluck(:id)).to eq([ownership.id])
        end
      end
      context "with deleted user_registration_organization" do
        it "does not create" do
          expect(bike.reload.user&.id).to be_present
          expect(bike.bike_organizations.pluck(:organization_id)).to eq([organization.id])
          expect(bike.ownerships.pluck(:id)).to eq([ownership.id])
          expect(ownership.registration_info).to eq({})
          user_registration_organization = user.user_registration_organizations.create(organization: organization)
          user_registration_organization.destroy
          expect(UserRegistrationOrganization.unscoped.count).to eq 1
          expect(user.user_registration_organizations.count).to eq 0
          instance.perform(bike.id)
          expect(UserRegistrationOrganization.unscoped.count).to eq 1
          expect(user_registration_organization.reload.deleted?).to be_truthy
          expect(user.reload.user_registration_organizations.count).to eq 0
        end
      end
      context "with paid organization" do
        let(:organization) { FactoryBot.create(:organization_with_organization_features) }
        let!(:bike2) { FactoryBot.create(:bike, :with_ownership_claimed, user: user, creation_registration_info: registration_info) }
        let(:registration_info) { default_location_registration_address.merge(phone: "1112223333", student_id: "ffffff") }
        it "creates with all_bikes" do
          expect(bike.bike_organizations.pluck(:organization_id)).to eq([organization.id])
          expect(bike.ownerships.pluck(:id)).to eq([ownership.id])
          expect(ownership.registration_info).to eq({})
          expect(bike2.reload.bike_organizations.pluck(:organization_id)).to eq([])
          expect(bike2.registration_info).to eq registration_info.as_json
          expect(UserRegistrationOrganization.unscoped.count).to eq 0
          expect(user.user_registration_organizations.count).to eq 0
          instance.perform(bike.id)
          expect(UserRegistrationOrganization.unscoped.count).to eq 1
          expect(user.reload.user_registration_organizations.count).to eq 1
          user_registration_organization = user.reload.user_registration_organizations.first
          expect(user_registration_organization.organization_id).to eq organization.id
          expect(user_registration_organization.all_bikes).to be_truthy
          expect(user_registration_organization.bikes.pluck(:id)).to match_array([bike.id, bike2.id])
          expect(user_registration_organization.registration_info).to eq registration_info.as_json
          expect(bike.reload.bike_organizations.pluck(:organization_id)).to eq([organization.id])
          expect(bike.ownerships.pluck(:id)).to eq([ownership.id])
          expect(bike.registration_info).to eq registration_info.as_json
          expect(ownership.reload.registration_info).to eq registration_info.as_json
          expect(bike_organization.reload.organization_id).to eq organization.id
          expect(bike_organization.overridden_by_user_registration?).to be_truthy
          expect(ownership.reload.registration_info).to eq registration_info.as_json
          expect(ownership.overridden_by_user_registration?).to be_truthy
          bike2.reload
          expect(bike2.bike_organizations.pluck(:organization_id)).to eq([organization.id])
          expect(bike2.bike_organizations.first.overridden_by_user_registration?).to be_truthy
        end
      end
    end
  end

  describe "serialized" do
    let!(:bike) { FactoryBot.create(:stolen_bike) }
    it "doesn't call the webhook" do
      expect_any_instance_of(Faraday::Connection).to_not receive(:post) { true }
      instance.post_bike_to_webhook(instance.serialized(bike))
    end
    context "with webhook url set" do
      it "calls the things we expect it to call" do
        stub_const("::Callbacks::AfterBikeSaveJob::POST_URL", "https://example.com")
        expect_any_instance_of(Faraday::Connection).to receive(:post) { true }
        instance.post_bike_to_webhook(instance.serialized(bike))
      end
    end
  end

  describe "remove_partial_registrations" do
    let(:organization) { FactoryBot.create(:organization) }
    let!(:partial_registration) { FactoryBot.create(:b_param_partial_registration, owner_email: "stuff@things.COM", origin: "embed_partial", organization: organization) }
    let(:bike) { FactoryBot.create(:bike, owner_email: "stuff@things.com") }
    let(:user) { FactoryBot.create(:user_confirmed, email: "stuff@things.com") }
    let!(:ownership) { FactoryBot.create(:ownership, bike: bike, creator: user) }
    before { bike.reload } # Because current_ownership
    it "assigns the partial registration" do
      expect(bike.creation_organization_id).to be_blank
      expect(bike.current_ownership.organization_id).to be_blank
      expect(bike.current_ownership.origin).to eq "web"
      expect(partial_registration.partial_registration?).to be_truthy
      expect(partial_registration.with_bike?).to be_falsey
      instance.perform(bike.id)
      partial_registration.reload
      expect(partial_registration.with_bike?).to be_truthy
      expect(partial_registration.created_bike).to eq bike
      bike.reload
      expect(bike.creation_organization_id).to eq organization.id # TODO: Remove when creation_organization_id deleted
      expect(bike.current_ownership.organization_id).to eq organization.id
      expect(bike.current_ownership.origin).to eq "embed_partial"
      expect(bike.organizations.pluck(:id)).to eq([organization.id])
      expect(bike.editable_organizations.pluck(:id)).to eq([organization.id])
    end
    context "bike already has organization" do
      let!(:ownership) { FactoryBot.create(:ownership, bike: bike, creator: user, organization: FactoryBot.create(:organization)) }
      it "does not assign" do
        og_organization_id = ownership.organization_id
        expect(bike.current_ownership.organization_id).to be_present
        expect(bike.current_ownership.origin).to eq "web"
        expect(partial_registration.partial_registration?).to be_truthy
        expect(partial_registration.with_bike?).to be_falsey
        instance.perform(bike.id)
        partial_registration.reload
        expect(partial_registration.with_bike?).to be_truthy
        expect(partial_registration.created_bike).to eq bike
        bike.reload
        expect(bike.current_ownership.organization_id).to eq og_organization_id
        expect(bike.current_ownership.origin).to eq "web"
      end
    end
    context "creation state isn't web" do
      let!(:ownership) { FactoryBot.create(:ownership, bike: bike, creator: user, origin: "api_v2") }
      it "doesn't assign" do
        expect(bike.creation_organization_id).to be_blank
        expect(bike.current_ownership.organization_id).to be_blank
        expect(bike.current_ownership.origin).to eq "api_v2"
        expect(partial_registration.partial_registration?).to be_truthy
        expect(partial_registration.with_bike?).to be_falsey
        instance.perform(bike.id)
        partial_registration.reload
        expect(partial_registration.with_bike?).to be_truthy
        expect(partial_registration.created_bike).to eq bike
        bike.reload
        expect(bike.current_ownership.organization_id).to be_blank
        expect(bike.current_ownership.origin).to eq "api_v2"
        expect(bike.organizations.pluck(:id)).to eq([])
      end
    end
    context "with a more accurate match" do
      let(:manufacturer) { bike.manufacturer }
      let!(:partial_registration_accurate) { FactoryBot.create(:b_param_partial_registration, owner_email: "STUFF@things.com", manufacturer: manufacturer) }
      it "only removes the more accurate match" do
        expect(partial_registration.partial_registration?).to be_truthy
        expect(partial_registration.with_bike?).to be_falsey
        expect(partial_registration_accurate.partial_registration?).to be_truthy
        expect(partial_registration_accurate.with_bike?).to be_falsey
        instance.perform(bike.id)
        partial_registration.reload
        partial_registration_accurate.reload
        expect(partial_registration.with_bike?).to be_falsey
        expect(partial_registration_accurate.with_bike?).to be_truthy
        expect(partial_registration_accurate.created_bike).to eq bike
        bike.reload
        expect(bike.current_ownership.origin).to eq "embed_partial"
      end
    end
  end

  describe "versions" do
    let(:bike) { FactoryBot.create(:bike) }
    let!(:bike_version) { FactoryBot.create(:bike_version, bike: bike) }
    let(:update_attributes) do
      {
        frame_material: "steel",
        frame_size: "xxl",
        manufacturer_id: Manufacturer.other.id,
        manufacturer_other: "Some cool thing",
        year: 1969
      }
    end
    it "makes the things equal" do
      bike.update(update_attributes)
      instance.perform(bike.id)
      expect(bike_version.reload).to match_hash_indifferently update_attributes
      expect(bike_version.mnfg_name).to eq "Some cool thing"
      expect(bike_version.frame_size_unit).to eq "ordinal"
    end
  end

  describe "motorized" do
    let(:bike) { FactoryBot.create(:bike, propulsion_type: "throttle", frame_model: "something") }
    it "enqueues FindOrCreateModelAuditJob" do
      expect(bike.reload.motorized?).to be_truthy
      Sidekiq::Job.clear_all
      instance.perform(bike.id)
      expect(Sidekiq::Job.jobs.map { |j| j["class"] }.sort).to eq(%w[DuplicateBikeFinderJob FindOrCreateModelAuditJob])
      expect(ModelAudit.count).to eq 0
      FindOrCreateModelAuditJob.drain
      expect(bike.reload.model_audit_id).to be_present
    end
  end
end
