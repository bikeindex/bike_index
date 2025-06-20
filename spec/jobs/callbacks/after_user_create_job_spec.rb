require "rails_helper"

RSpec.describe Callbacks::AfterUserCreateJob, type: :job do
  let(:instance) { described_class.new }

  let!(:user) { FactoryBot.create(:user, email: "owner1@A.COM") }
  let(:email) { user.email }

  before { Sidekiq::Job.clear_all }

  describe "perform" do
    context "stage: new" do
      let(:user) { User.new(id: 69, email: "owner@jess.com") }
      it "sends confirmation email" do
        expect(instance).to receive(:associate_organization_role_invites).and_return(true)
        expect {
          instance.perform(user.id, "new", user: user)
        }.to change(::Callbacks::AfterUserCreateJob.jobs, :count).by 1
        expect(Email::ConfirmationJob.jobs.map { |j| j["args"] }.flatten).to eq([user.id])
        expect(::Callbacks::AfterUserCreateJob.jobs.map { |j| j["args"] }.last.flatten).to eq([user.id, "async"])
      end

      context "confirmed user" do
        it "sends welcome email" do
          allow(user).to receive(:confirmed?) { true }
          expect {
            instance.perform(user.id, "new", user: user)
          }.to change(::Callbacks::AfterUserCreateJob.jobs, :count).by 1
          expect(Email::WelcomeJob.jobs.map { |j| j["args"] }.flatten).to eq([user.id])
          expect(::Callbacks::AfterUserCreateJob.jobs.map { |j| j["args"] }.last.flatten).to eq([user.id, "async"])
        end
      end
    end

    context "stage: confirmed" do
      it "associates" do
        expect(UserEmail).to receive(:create_confirmed_primary_email).with(user)
        expect {
          instance.perform(user.id, "confirmed", user: user)
        }.to change(::Callbacks::AfterUserCreateJob.jobs, :count).by 1
        expect(::Callbacks::AfterUserCreateJob.jobs.map { |j| j["args"] }.last.flatten).to eq([user.id, "async"])
      end
    end

    context "stage: merged" do
      it "associates" do
        expect(instance).to receive(:associate_ownerships)
        expect(instance).to receive(:associate_organization_role_invites)
        expect {
          instance.perform(user.id, "merged", user: user)
        }.to_not change(::Callbacks::AfterUserCreateJob.jobs, :count)
      end
    end

    context "stage: async" do
      it "calls import" do
        expect(instance).to_not receive(:associate_ownerships)
        expect(instance).to receive(:import_user_attributes)
        expect {
          instance.perform(user.id, "async")
        }.to_not change(::Callbacks::AfterUserCreateJob.jobs, :count)
      end
      context "confirmed user" do
        let(:user) { FactoryBot.create(:user_confirmed) }
        it "calls import and associate_ownerships" do
          expect(instance).to receive(:associate_ownerships)
          expect(instance).to receive(:import_user_attributes)
          expect {
            instance.perform(user.id, "async")
          }.to_not change(::Callbacks::AfterUserCreateJob.jobs, :count)
        end
      end
    end
  end

  describe "associate_ownerships" do
    let(:bike) { FactoryBot.create(:bike, owner_email: "owner1@a.com") }
    let!(:ownership) { FactoryBot.create(:ownership, owner_email: "OWner1@a.com", bike: bike) }
    let(:bike2) { FactoryBot.create(:bike, owner_email: "owner1@a.com") }
    let!(:ownership2) { FactoryBot.create(:ownership, owner_email: "owner1@a.com", bike: bike2) }
    let(:bike3) { FactoryBot.create(:bike, owner_email: "owner1@a.com") }
    let!(:ownership3) { FactoryBot.create(:ownership, owner_email: "owner1@a.com", bike: bike3) }

    it "assigns any ownerships that match the user email" do
      expect(user).to be_present
      ownerships = [ownership, ownership2, ownership3]
      ownerships.each { |o| expect(o.user).to be_nil }
      instance.associate_ownerships(user, email)

      ownerships.each do |o|
        o.reload
        expect(o.user).to eq user
      end
    end
  end

  context "extra user attributes" do
    # Block traditional run, so we can do it separately }
    before { allow_any_instance_of(User).to receive(:perform_create_jobs) { true } }
    let(:user) { FactoryBot.create(:user, email: "aftercreate@bikeindex.org") }
    let!(:state) { FactoryBot.create(:state_california) }
    let!(:country) { Country.united_states }
    let(:target_address_hash) { {street: "Pier 15, The Embarcadero", city: "San Francisco", state: "CA", zipcode: "94111", country: "US", latitude: 37.8016649, longitude: -122.397348} }
    let(:bike) do
      FactoryBot.create(:bike,
        :with_ownership_claimed,
        owner_email: "aftercreate@bikeindex.org",
        user: user,
        creation_registration_info: {phone: "(111) 222-3333"}.merge(target_address_hash))
    end
    include_context :geocoder_real
    it "assigns the extra user attributes" do
      VCR.use_cassette("after_user_create_worker-import_user_attributes") do
        expect(user).to be_present
        bike.reload.update(updated_at: Time.current)
        expect(bike.reload.registration_address_source).to eq "initial_creation"
        expect(bike.to_coordinates).to eq([target_address_hash[:latitude], target_address_hash[:longitude]])
        expect(BikeServices::CalculateStoredLocation.location_attrs(bike)).to match_hash_indifferently target_address_hash.except(:latitude, :longitude).merge(skip_geocoding: false)

        Sidekiq::Testing.inline! { instance.perform(user.id, "new") }
        user.reload

        expect(user.phone).to eq "1112223333"
        expect(user.address_hash_legacy).to eq target_address_hash.merge(country: "United States").as_json
        expect(user.to_coordinates).to eq([37.8016649, -122.397348])
      end
    end
    context "existing attributes" do
      let(:user) { FactoryBot.create(:user, email: "aftercreate@bikeindex.org", phone: "929292", zipcode: "89999") }
      it "doesn't import" do
        instance.perform(user.id, "new")
        user.reload
        expect(user.phone).to eq "929292"
        expect(user.street).to be_nil
        expect(user.city).to be_nil
        expect(user.zipcode).to eq "89999"
        expect(user.state_id).to be_nil
        expect(user.country_id).to be_nil
      end
    end
  end

  describe "associate_organization_role_invites" do
    it "assigns any organization_roles that match the user email, and mark user confirmed if invited", :flaky do
      user = FactoryBot.build(:user, email: "owner1@B.COM")
      organization_role1 = FactoryBot.create(:organization_role, invited_email: " #{user.email.upcase}")
      organization_role2 = FactoryBot.create(:organization_role, invited_email: " #{user.email.upcase}")
      expect(organization_role1.claimed?).to be_falsey

      Sidekiq::Testing.inline! { user.save }

      expect(organization_role1.created_at < user.created_at).to be_truthy
      # This is called on create, so we just test that things happen correctly here
      expect(user.confirmed?).to be_truthy
      expect(organization_role1.reload.claimed?).to be_truthy
      expect(organization_role2.reload.claimed?).to be_truthy
      expect(organization_role1.user).to eq user
      expect(user.organization_roles.count).to eq 2
      expect(user.organizations.count).to eq 2
    end

    # We are processing the first organization inline so we can
    # redirect users to the organization they belong to
    it "synchronously associates the first memberhsip", :flaky do
      user = FactoryBot.build(:user, email: "owner1@B.COM")
      organization_role1 = FactoryBot.create(:organization_role, invited_email: " #{user.email.upcase}")
      organization_role2 = FactoryBot.create(:organization_role, invited_email: " #{user.email.upcase}")
      expect(organization_role1).to_not be_claimed
      expect(organization_role2).to_not be_claimed

      user.save

      expect(organization_role1.reload.created_at).to be < user.created_at
      expect(user).to be_confirmed
      expect(organization_role1).to be_claimed
      expect(organization_role1.user).to eq user
      expect(user.organization_roles.count).to eq(1)
      expect(user.organizations.count).to eq(1)
    end
  end

  describe "send_welcoming_email" do
    let(:user) { User.new(id: 69) }
    it "enques enqueues confirmation email" do
      instance.send_welcoming_email(user)
      expect(Email::ConfirmationJob).to have_enqueued_sidekiq_job(69)
    end
    context "confirmed user" do
      it "enques welcome email" do
        allow(user).to receive(:confirmed?) { true }
        instance.send_welcoming_email(user)
        expect(Email::WelcomeJob.jobs.map { |j| j["args"] }.flatten).to eq([user.id])
      end
    end
  end

  context "organization with auto passwordless users" do
    let!(:organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: ["passwordless_users"], passwordless_user_domain: "city.gov", available_invitation_count: 1) }
    let(:user) { FactoryBot.create(:user, email: email) }
    let(:email) { "example@somethingcity.gov" }
    it "does not become member for non-matching domain" do
      user.reload
      expect(user.confirmed?).to be_falsey
      # This is called inline on the user, but doing it here, to more accurately model what happens
      Sidekiq::Job.clear_all
      ActionMailer::Base.deliveries = []
      Sidekiq::Testing.inline! { user.confirm(user.confirmation_token) }
      expect(ActionMailer::Base.deliveries.count).to eq 0
      user.reload
      expect(user.confirmed?).to be_truthy
      expect(user.organization_roles.count).to eq 0
    end
    context "matching domain" do
      let(:email) { "example@city.gov" }
      it "creates the organization_role on confirm" do
        user.reload
        expect(user.confirmed?).to be_falsey
        Sidekiq::Job.clear_all
        ActionMailer::Base.deliveries = []
        Sidekiq::Testing.inline! { user.confirm(user.confirmation_token) }
        user.reload
        expect(user.confirmed?).to be_truthy
        expect(user.organization_roles.count).to eq 1
        expect(user.mailchimp_datum).to be_blank
        organization_role = user.organization_roles.first
        expect(organization_role.claimed?).to be_truthy
        expect(organization_role.organization_id).to eq organization.id
        expect(organization_role.role).to eq "member"

        expect(ActionMailer::Base.deliveries.count).to eq 1
        mail = ActionMailer::Base.deliveries.last
        expect(mail.subject).to match(/join.*#{organization.name}/i)
      end
      context "organization_role exists" do
        it "does not create an additional organization_role" do
          expect(user.confirmed?).to be_falsey
          organization_role = FactoryBot.create(:organization_role, user: user, sender: nil, organization: organization, role: "admin")
          expect(organization_role.claimed?).to be_truthy
          user.reload
          expect(user.mailchimp_datum).to be_blank
          Sidekiq::Job.clear_all
          ActionMailer::Base.deliveries = []
          expect {
            Sidekiq::Testing.inline! { user.confirm(user.confirmation_token) }
          }.to_not change(OrganizationRole, :count)
          expect(ActionMailer::Base.deliveries.count).to eq 0
          user.reload
          expect(user.confirmed?).to be_truthy
          expect(user.organization_roles.count).to eq 1
          organization_role.reload
          expect(organization_role.organization_id).to eq organization.id
          expect(organization_role.role).to eq "admin"
          expect(user.mailchimp_datum).to be_present
        end
      end
    end
  end

  describe "graduated_notification" do
    let!(:graduated_notification) { FactoryBot.create(:graduated_notification_bike_graduated) }
    let(:bike) { graduated_notification.bike }
    let(:user) { FactoryBot.create(:user_confirmed, email: bike.owner_email.upcase) }

    it "assigns any that match the user email" do
      expect(bike.reload.claimed?).to be_falsey
      expect(bike.current_ownership.user&.id).to be_blank
      expect(graduated_notification.bike_graduated?).to be_truthy
      expect(graduated_notification.primary_notification?).to be_truthy
      expect(graduated_notification.user_id).to be_blank
      og_updated_at = graduated_notification.reload.updated_at
      expect(user).to be_present

      Sidekiq::Testing.inline! { instance.perform(user.id, "confirmed") }

      expect(bike.reload.claimed?).to be_falsey
      expect(bike.current_ownership.user&.id).to eq user.id
      expect(graduated_notification.reload.user_id).to eq user.id
      expect(graduated_notification.updated_at).to eq og_updated_at # Shouldn't have changed
    end
  end
end
