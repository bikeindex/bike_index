require "rails_helper"

RSpec.describe BikeJobs::MergePosRegistrationJob, type: :job do
  let(:instance) { described_class.new }
  let(:match) { FactoryBot.create(:pos_registration_match, status: :confirmed) }
  let(:bike) { match.bike }
  let(:pos_bike) { match.pos_bike }
  let(:user) { bike.user }
  let(:organization) { pos_bike.bike_organizations.first.organization }

  # Written because UserJobs::MergeAdditionalEmailJob left impound updates and claims on the old user (#4777)
  it "moves or lists every column that can point at a bike" do
    bike_id_columns = ActiveRecord::Base.connection.select_rows("SELECT table_name, column_name FROM information_schema.columns " \
      "WHERE column_name LIKE '%bike_id' AND table_schema = 'public'").map { it.join(".") }
    # Associations to Bike named something else, e.g. impound_claims.bike_claimed_id, and polymorphic ones
    Rails.application.eager_load!
    association_columns = ApplicationRecord.descendants.reject(&:abstract_class?).flat_map do |model|
      model.reflect_on_all_associations(:belongs_to).select { it.polymorphic? || it.class_name == "Bike" }
        .map { "#{model.table_name}.#{it.foreign_key}" }
    end
    expect((bike_id_columns + association_columns).uniq).to match_array(described_class::MOVED_MODELS.map { "#{it.table_name}.bike_id" } +
      described_class::MERGED_COLUMNS + described_class::LEFT_COLUMNS.keys)
  end

  context "when it merges" do
    context "with what the owner added" do
      let!(:public_image) { FactoryBot.create(:public_image, imageable: bike) }
      let!(:private_image) { FactoryBot.create(:public_image, imageable: bike, is_private: true) }
      let!(:component) { FactoryBot.create(:component, bike:) }
      let!(:bike_sticker) { FactoryBot.create(:bike_sticker_claimed, bike:, user:) }
      let!(:bike_organization) { FactoryBot.create(:bike_organization, bike:) }
      let!(:customer_contact) { FactoryBot.create(:customer_contact, bike:) }
      let!(:notification) { FactoryBot.create(:notification, user:, bike:, kind: :finished_registration) }
      let!(:vehicle_specification) { VehicleSpecification.create!(bike_obj: bike, bikebook_market: "CA") }
      let!(:pos_vehicle_specification) { VehicleSpecification.create!(bike_obj: pos_bike, bikebook_model_id: 12, bikebook_market: "US") }
      before do
        bike.update!(frame_model: "Roadster", year: 2024, description: "Red basket", propulsion_type: "pedal-assist")
        pos_bike.update!(year: 2023, marked_user_hidden: true)
        bike.current_ownership.update!(registration_info: {"phone" => "7183839292"})
      end

      it "keeps the POS registration, with what the owner added, and deletes theirs" do
        expect(pos_bike.reload.user_hidden).to be_truthy
        instance.perform(match.id)
        # What the owner entered wins
        expect(pos_bike.reload).to have_attributes(frame_model: "Roadster", year: 2024, description: "Red basket",
          propulsion_type: "pedal-assist", user_hidden: false)
        expect([public_image, private_image].map { PublicImage.unscoped.find(it.id).imageable_id }).to eq([pos_bike.id] * 2)
        expect([component, bike_sticker, bike_organization, customer_contact, notification].map { it.reload.bike_id })
          .to eq([pos_bike.id] * 5)
        expect(pos_bike.current_ownership.reload).to have_attributes(claimed: true, registration_info: {"phone" => "7183839292"})
        expect(pos_vehicle_specification.reload).to have_attributes(bikebook_model_id: 12, bikebook_market: "CA")
        expect(VehicleSpecification.exists?(vehicle_specification.id)).to be_falsey
        expect(match.reload).to have_attributes(status: "merged", merged_at: be_within(1.minute).of(Time.current))
        expect(Bike.unscoped.find(bike.id).deleted_at).to be_present
        expect(CallbackJobs::AfterBikeSaveJob.jobs.map { it["args"] }).to include([bike.id], [pos_bike.id])
        expect(PosRegistrationMatch.merged_into(Bike.unscoped.find(bike.id))).to eq pos_bike
      end
    end

    context "with the owner's defaults and blanks, and the shop's organization" do
      let!(:pos_bike_note) { FactoryBot.create(:bike_organization_note, bike: pos_bike, organization:) }
      let!(:bike_note) { FactoryBot.create(:bike_organization_note, bike:, organization:) }
      let!(:other_note) { FactoryBot.create(:bike_organization_note, bike:, organization: FactoryBot.create(:organization)) }
      let(:address_record) { FactoryBot.create(:address_record, kind: :ownership) }
      let(:strava_integration) { FactoryBot.create(:strava_integration, user:) }
      let!(:strava_gear) { FactoryBot.create(:strava_gear, item: bike, strava_integration:) }
      before do
        pos_bike.update!(propulsion_type: "pedal-assist", description: "Shop notes", frame_size: "56cm")
        bike.update_columns(description: "", frame_size: "m", frame_size_number: nil, frame_size_unit: "ordinal")
        FactoryBot.create(:bike_organization, bike:, organization:, can_not_edit_claimed: true)
        bike.current_ownership.update!(address_record:)
      end

      it "takes the owner's defaults and blanks too, and keeps the shop's organization permission and note" do
        expect(bike.reload.propulsion_type).to eq "foot-pedal"
        instance.perform(match.id)
        expect(pos_bike.reload).to have_attributes(propulsion_type: "foot-pedal", description: "", frame_size: "m",
          frame_size_number: nil, frame_size_unit: "ordinal")
        expect(pos_bike.bike_organizations.find_by(organization:).can_not_edit_claimed).to be_truthy
        expect([pos_bike_note, bike_note, other_note].map { it.reload.bike_id }).to eq([pos_bike.id, bike.id, pos_bike.id])
        expect(pos_bike.current_ownership.address_record_id).to eq address_record.id
        expect(strava_gear.reload.item_id).to eq pos_bike.id
      end
    end

    # Written because re-claiming a sticker of the POS registration's organization failed the merge on every retry
    context "with the shop's sticker, and the owner's submission, impound claim and alert" do
      let(:sticker_claimer) { FactoryBot.create(:user) }
      let!(:bike_sticker) { FactoryBot.create(:bike_sticker_claimed, bike:, user: sticker_claimer, organization:) }
      let!(:b_param) { FactoryBot.create(:b_param, created_bike_id: bike.id) }
      let!(:impound_claim) { FactoryBot.create(:impound_claim) }
      let!(:user_alert) do
        FactoryBot.create(:user_alert, kind: "unassigned_bike_org", user:, bike:, organization: FactoryBot.create(:organization))
      end
      before { impound_claim.update_column(:bike_submitting_id, bike.id) }

      it "moves the sticker without re-claiming it, and the submission and impound claim, and resolves the alert" do
        claimed_at = bike_sticker.reload.claimed_at
        instance.perform(match.id)
        expect(match.reload.status).to eq "merged"
        expect(bike_sticker.reload).to have_attributes(bike_id: pos_bike.id, previous_bike_id: bike.id,
          user_id: sticker_claimer.id, claimed_at:)
        expect(bike_sticker.bike_sticker_updates.order(:id).last).to have_attributes(bike_id: pos_bike.id, user_id: nil, kind: "re_claim")
        expect(b_param.reload.created_bike_id).to eq pos_bike.id
        expect(impound_claim.reload.bike_submitting_id).to eq pos_bike.id
        expect(user_alert.reload.resolved?).to be_truthy
      end
    end

    context "with a graduated notification" do
      let(:organization) do
        FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: ["graduated_notifications"],
          graduated_notification_interval: 1.year)
      end
      let!(:bike_organization) { FactoryBot.create(:bike_organization, bike:, organization:) }
      let!(:graduated_notification) { FactoryBot.create(:graduated_notification, bike:, organization:) }

      context "when the POS registration is in the organization too" do
        let!(:pos_bike_organization) { FactoryBot.create(:bike_organization, bike: pos_bike, organization:) }

        it "points the moved notification at the kept bike's organization" do
          expect(graduated_notification.reload.bike_organization_id).to eq bike_organization.id
          instance.perform(match.id)
          expect(match.reload.status).to eq "merged"
          expect(graduated_notification.reload).to have_attributes(bike_id: pos_bike.id, bike_organization_id: pos_bike_organization.id)
        end
      end

      context "when the owner's membership graduated" do
        before { bike_organization.destroy! }

        it "moves the membership, so its renewal link restores the kept bike's" do
          expect(graduated_notification.reload.bike_organization_id).to eq bike_organization.id
          instance.perform(match.id)
          expect(match.reload.status).to eq "merged"
          expect(BikeOrganization.unscoped.find(bike_organization.id).bike_id).to eq pos_bike.id
          expect(graduated_notification.reload).to have_attributes(bike_id: pos_bike.id, bike_organization_id: bike_organization.id)
        end
      end
    end

    context "with graduated memberships" do
      let(:organization) { FactoryBot.create(:organization) }

      context "when the owner's was more restrictive" do
        let!(:pos_bike_organization) { FactoryBot.create(:bike_organization, bike: pos_bike, organization:) }
        let!(:bike_organization) { FactoryBot.create(:bike_organization, bike:, organization:, can_not_edit_claimed: true) }
        before { [pos_bike_organization, bike_organization].each(&:destroy!) }

        it "keeps the owner's restriction" do
          instance.perform(match.id)
          expect(match.reload.status).to eq "merged"
          expect(BikeOrganization.unscoped.find(pos_bike_organization.id).can_not_edit_claimed).to be_truthy
        end
      end

      context "when the POS registration's was more restrictive" do
        let!(:bike_organization) { FactoryBot.create(:bike_organization, bike:, organization:) }
        before { FactoryBot.create(:bike_organization, bike: pos_bike, organization:, can_not_edit_claimed: true).destroy! }

        it "keeps its restriction on the moved membership" do
          instance.perform(match.id)
          expect(bike_organization.reload).to have_attributes(bike_id: pos_bike.id, can_not_edit_claimed: true)
        end
      end

      # Written because a graduated restriction of the POS registration's own restricted its current membership
      context "when only the POS registration was in the organization" do
        let(:pos_bike_organization) { FactoryBot.create(:bike_organization, bike: pos_bike, organization:) }
        before { FactoryBot.create(:bike_organization, bike: pos_bike, organization:, can_not_edit_claimed: true).destroy! }

        it "leaves its memberships as they were" do
          # Re-added after the restricted one graduated
          expect(pos_bike_organization.can_not_edit_claimed).to be_falsey
          instance.perform(match.id)
          expect(match.reload.status).to eq "merged"
          expect(pos_bike_organization.reload.can_not_edit_claimed).to be_falsey
        end
      end

      context "when the owner's restricted membership graduated and they rejoined" do
        let(:bike_organization) { FactoryBot.create(:bike_organization, bike:, organization:) }
        before do
          FactoryBot.create(:bike_organization, bike: pos_bike, organization:).destroy!
          FactoryBot.create(:bike_organization, bike:, organization:, can_not_edit_claimed: true).destroy!
        end

        it "restricts every kept membership" do
          # Rejoined after the restricted one graduated
          expect(bike_organization.can_not_edit_claimed).to be_falsey
          instance.perform(match.id)
          expect(match.reload.status).to eq "merged"
          expect(BikeOrganization.unscoped.where(bike_id: pos_bike.id, organization:).pluck(:can_not_edit_claimed)).to eq([true, true])
          expect(bike_organization.reload).to have_attributes(bike_id: pos_bike.id, can_not_edit_claimed: true)
        end
      end
    end

    context "with another athlete's Strava gear" do
      let!(:strava_gear) { FactoryBot.create(:strava_gear, item: bike) }

      it "leaves the gear" do
        instance.perform(match.id)
        expect(match.reload.status).to eq "merged"
        expect(strava_gear.reload.item_id).to eq bike.id
      end
    end
  end

  # Sidekiq retries it, then it's dead and in Honeybadger
  context "when the merge fails" do
    let!(:component) { FactoryBot.create(:component, bike:) }
    before { allow_any_instance_of(Bike).to receive(:destroy!).and_raise(ActiveRecord::RecordNotDestroyed) }

    it "raises, leaving nothing half-merged" do
      expect { instance.perform(match.id) }.to raise_error(ActiveRecord::RecordNotDestroyed)
      expect(component.reload.bike_id).to eq bike.id
      expect(match.reload).to have_attributes(status: "confirmed", review_reasons: [], merged_at: nil)
      expect(bike.reload.deleted_at).to be_blank
      expect(CallbackJobs::AfterBikeSaveJob.jobs).to be_empty
    end
  end

  context "when it doesn't merge" do
    let(:other_bike) { FactoryBot.create(:bike, :with_ownership_claimed, user:, manufacturer: bike.manufacturer, serial_number: bike.serial_number) }

    context "with another registration of the POS registration" do
      let!(:other_match) { FactoryBot.create(:pos_registration_match, pos_bike:, bike: other_bike) }

      it "records why" do
        expect(other_match.reload.review_reasons).to eq []
        instance.perform(match.id)
        expect(match.reload).to have_attributes(status: "confirmed", review_reasons: ["multiple_registrations"])
        expect(bike.reload.deleted_at).to be_blank
      end
    end

    context "with a merged registration of the POS registration that came first" do
      before do
        FactoryBot.create(:pos_registration_match, pos_bike:, bike: other_bike, status: :merged)
        other_bike.destroy!
      end

      it "records why" do
        instance.perform(match.id)
        expect(match.reload).to have_attributes(status: "confirmed", review_reasons: ["multiple_registrations"])
      end
    end

    context "while their registration is mid-transfer" do
      before do
        ownership = bike.current_ownership
        FactoryBot.create(:ownership, bike:, creator: user, owner_email: "new-owner@example.com")
        # The new ownership is committed, but its after_commit hasn't pointed the bike at it yet
        ownership.update_column(:current, true)
        bike.update_column(:current_ownership_id, ownership.id)
      end

      it "records why" do
        instance.perform(match.id)
        expect(match.reload).to have_attributes(status: "confirmed", review_reasons: ["changed_since_confirmed"])
        expect(bike.reload.deleted_at).to be_blank
      end
    end

    context "when the POS registration is really deleted" do
      before { BikeJobs::BikeDeleterJob.new.perform(pos_bike.id, true) }

      it "records why" do
        instance.perform(match.id)
        expect(match.reload).to have_attributes(status: "confirmed", review_reasons: ["changed_since_confirmed"])
        expect(bike.reload.deleted_at).to be_blank
      end
    end

    context "with a theft since the answer" do
      before { FactoryBot.create(:stolen_bike, serial_number: bike.serial_number) }

      it "records it and leaves the match confirmed" do
        instance.perform(match.id)
        expect(match.reload).to have_attributes(status: "confirmed", review_reasons: ["stolen_history"])
        expect(bike.reload.deleted_at).to be_blank
        expect(CallbackJobs::AfterBikeSaveJob.jobs).to be_empty
      end
    end

    # Written because a stolen serial edited onto the POS registration slipped past the veto
    context "when a serial was edited" do
      before do
        pos_bike.update!(serial_number: "OTHER98765")
        FactoryBot.create(:stolen_bike, serial_number: "OTHER98765")
      end

      it "records why" do
        instance.perform(match.id)
        expect(match.reload).to have_attributes(status: "confirmed", review_reasons: ["changed_since_confirmed"])
        expect(match.merging?).to be_falsey
        expect(bike.reload.deleted_at).to be_blank
      end
    end

    context "when the POS registration is someone else's" do
      before { BikeServices::OwnershipTransferer.find_or_create(pos_bike, updator: user, new_owner_email: "new-owner@example.com") }

      it "records why" do
        instance.perform(match.id)
        expect(match.reload.review_reasons).to eq ["changed_since_confirmed"]
        expect(bike.reload.deleted_at).to be_blank
      end
    end

    context "when the match isn't confirmed" do
      let(:match) { FactoryBot.create(:pos_registration_match) }

      it "leaves it pending" do
        instance.perform(match.id)
        expect(match.reload.status).to eq "pending"
        expect(bike.reload.deleted_at).to be_blank
      end
    end
  end
end
