require "spec_helper"

describe AfterUserCreateWorker do
  let(:subject) { AfterUserCreateWorker }
  let(:instance) { subject.new }

  let!(:user) { FactoryBot.create(:user, email: "owner1@A.COM") }
  let(:email) { user.email }

  describe "perform" do
    context "state: new" do
      let(:user) { User.new(id: 69, email: "owner@jess.com") }
      it "sends confirmation email" do
        expect(instance).to receive(:associate_membership_invites).and_return(true)
        instance.perform(user.id, "new", user: user)
        expect(EmailConfirmationWorker).to have_enqueued_sidekiq_job(69)
      end

      context "confirmed user" do
        it "sends welcome email" do
          allow(user).to receive(:confirmed?) { true }
          instance.perform(user.id, "new", user: user)
          expect(EmailWelcomeWorker).to have_enqueued_sidekiq_job(69)
        end
      end
    end

    context "state: confirmed" do
      it "associates" do
        expect(UserEmail).to receive(:create_confirmed_primary_email).with(user)
        expect(instance).to receive(:associate_ownerships)
        instance.perform(user.id, "confirmed", user: user)
      end
    end

    context "state: merged" do
      it "associates" do
        expect(instance).to receive(:associate_ownerships)
        expect(instance).to receive(:associate_membership_invites)
        instance.perform(user.id, "merged", user: user)
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
    let!(:state) { FactoryBot.create(:state, name: "California", abbreviation: "CA") }
    let!(:country) { Country.united_states }
    let!(:b_param) do
      FactoryBot.create(:b_param,
                        created_bike_id: bike.id,
                        creator: bike.creator,
                        params: { bike: { address: "Pier 15 The Embarcadero, 94111", phone: "(111) 222-3333" } })
    end
    # We need to manually set the user in this ownership because otherwise rspec can't find it TODO: Rails 5 update maybe
    let(:ownership) { FactoryBot.create(:ownership, user: user, owner_email: "aftercreate@bikeindex.org") }
    let!(:bike) { ownership.bike }
    include_context :geocoder_real
    it "assigns the extra user attributes" do
      VCR.use_cassette("after_user_create_worker-import_user_attributes") do
        expect(user).to be_present
        instance.perform(user.id, "new")
        ownership.reload
        user.reload
        expect(user.phone).to eq "1112223333"
        expect(user.street).to eq "Pier 15, The Embarcadero"
        expect(user.city).to eq "San Francisco"
        expect(user.zipcode).to eq "94111"
        expect(user.state).to eq state
        expect(user.country).to eq country
        expect([user.latitude, user.longitude]).to eq([37.8016649, -122.397348])
      end
    end
    context "existing attributes" do
      let(:user) { FactoryBot.create(:user, email: "aftercreate@bikeindex.org", phone: "929292", zipcode: "89999", skip_geocode: true) }
      it "doesn't import" do
        instance.perform(user.id, "new")
        user.reload
        expect(user.phone).to eq "929292"
        expect(user.street).to be_nil
        expect(user.city).to be_nil
        expect(user.zipcode).to eq "89999"
        expect(user.state).to be_nil
        expect(user.country).to be_nil
      end
    end
  end

  describe "associate_membership_invites" do
    let!(:organization_invitation) { FactoryBot.create(:organization_invitation, invitee_email: " #{user.email.upcase}") }
    let(:user) { FactoryBot.build(:user, email: "owner1@A.COM") }
    it "assigns any organization invitations that match the user email, and mark user confirmed if invited" do
      user.save
      expect(organization_invitation.created_at < user.created_at).to be_truthy
      # This is called on create, so we just test that things happen correctly here
      # Rather than stubbing stuff out - and to ensure that this actually happens inline
      user.reload
      expect(user.memberships.count).to eq 1
      expect(user.confirmed?).to be_truthy
    end
  end

  describe "send_welcoming_email" do
    let(:user) { User.new(id: 69) }
    it "enques enqueues confirmation email" do
      instance.send_welcoming_email(user)
      expect(EmailConfirmationWorker).to have_enqueued_sidekiq_job(69)
    end
    context "confirmed user" do
      it "enques welcome email" do
        allow(user).to receive(:confirmed?) { true }
        instance.send_welcoming_email(user)
        expect(EmailWelcomeWorker).to have_enqueued_sidekiq_job(69)
      end
    end
  end
end
