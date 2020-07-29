require "rails_helper"

RSpec.describe Appointment, type: :model do
  describe "factory" do
    let(:appointment) { FactoryBot.create(:appointment, status: "waiting") }
    it "is valid" do
      expect(appointment.valid?).to be_truthy
      expect(appointment.id).to be_present
      expect(appointment.in_line?).to be_truthy
      expect(appointment.signed_in_user?).to be_falsey
      expect(appointment.virtual_line?).to be_truthy
      expect(appointment.line_number).to eq 1
      # And it updates the queue
      expect {
        appointment.update(updated_at: Time.current)
      }.to change(LocationAppointmentsQueueWorker.jobs, :count).by 1
      expect(LocationAppointmentsQueueWorker.jobs.map { |j| j["args"] }.last.flatten).to eq([appointment.location_id])
    end
  end

  describe "for_user_attrs & matches_user_attrs?" do
    it "fails unless passed one arg" do
      expect {
        Appointment.for_user_attrs(email: "beth@STuff.com", user_id: 12)
      }.to raise_error(/one/)
      expect {
        Appointment.for_user_attrs(email: " ")
      }.to raise_error(/one/)
    end
    context "with appointments" do
      let(:user) { FactoryBot.create(:user_confirmed, email: "beth@stuff.com") }
      let(:appt1) { FactoryBot.create(:appointment, email: "BETH@stuff.com", creation_ip: "108.000.215.126") } # Invalid ip address
      let(:organization) { appt1.organization }
      let(:location) { appt1.location }
      let!(:appt2) { FactoryBot.create(:appointment, organization: organization, location: location, user: user) }
      let!(:appt3) { FactoryBot.create(:appointment, email: "elizabeth@EXAMPLE.com ", creation_ip: "108.100.215.126") }
      it "associates and finds them, etc" do
        # Create secondary email after the fact, so that the user isn't associated
        FactoryBot.create(:user_email, user: user, email: "elizabeth@example.com")
        appt1.reload
        appt2.reload
        appt3.reload
        expect(appt1.user_id).to be_blank
        expect(appt2.user_id).to eq user.id
        expect(appt2.creation_ip).to be_blank
        expect(appt3.user_id).to be_blank
        expect(appt3.creation_ip.to_s).to eq "108.100.215.126"

        expect(appt1.matches_user_attrs?(email: "beth@stuff.COM ")).to be_truthy
        expect(appt1.matches_user_attrs?(user_id: user.id)).to be_truthy
        expect(appt1.matches_user_attrs?(user: user)).to be_truthy
        # TODO: test that this ticket is assigned in after_user_create_worker
        # expect(appt1.matches_user_attrs?(email: "elizabeth@example.com ")).to be_truthy

        expect(appt2.matches_user_attrs?(email: "  beth@stuff.COM")).to be_truthy
        expect(appt2.matches_user_attrs?(user_id: user.id)).to be_truthy
        expect(appt2.matches_user_attrs?(user: user)).to be_truthy
        expect(appt2.matches_user_attrs?(email: "elizabeth@example.com ")).to be_truthy

        # TODO: test that this ticket is assigned in after_user_create_worker for secondary email
        # expect(appt3.matches_user_attrs?(email: "  beth@stuff.COM")).to be_truthy
        expect(appt3.matches_user_attrs?(user_id: user.id)).to be_truthy
        expect(appt3.matches_user_attrs?(user: user)).to be_truthy
        expect(appt3.matches_user_attrs?(email: "elizabeth@example.com ")).to be_truthy

        # Bumping the appointments results in the appointments being assigned
        appt1.update(updated_at: Time.current)
        appt3.update(updated_at: Time.current)
        appt1.reload
        appt3.reload
        expect(appt1.user_id).to eq user.id
        expect(appt3.user_id).to eq user.id
        expect(Appointment.for_user_attrs(email: "elizabeth@example.com").pluck(:id)).to match_array([appt1.id, appt2.id, appt3.id])
        expect(Appointment.for_user_attrs(email: "beth@STuff.com").pluck(:id)).to match_array([appt1.id, appt2.id, appt3.id])
        expect(Appointment.for_user_attrs(user_id: user.id).pluck(:id)).to match_array([appt1.id, appt2.id, appt3.id])
      end
    end
  end

  describe "public_display_name" do
    let(:user) { FactoryBot.build(:user, name: "fuck off") }
    let(:appointment) { Appointment.new(name: "NIggER bitch", user: user) }
    it "removes offensive things" do
      expect(appointment.name).to eq "NIggER bitch"
      expect(appointment.display_name).to eq "NIggER bitch"
      expect(appointment.public_display_name).to eq "******"
      appointment.name = ""
      expect(appointment.name).to eq ""
      expect(appointment.display_name).to eq "fuck off"
      expect(appointment.public_display_name).to eq "****"
    end
  end

  describe "record_status_update" do
    let!(:appointment) { FactoryBot.create(:appointment, status: og_status, line_number: 90) }
    let(:location) { appointment.location }
    let(:og_status) { "waiting" }
    let(:new_status) { "on_deck" }
    let(:updator_id) { nil }

    def expect_no_update(appt, og_status, new_status, updator_id, updator_kind)
      Sidekiq::Worker.clear_all
      expect {
        result = appt.record_status_update(new_status: new_status, updator_id: updator_id, updator_kind: updator_kind)
        expect(result).to be_blank
      }.to_not change(AppointmentUpdate, :count)
      expect(LocationAppointmentsQueueWorker.jobs.count).to eq 0
      appt.reload
      expect(appt.status).to eq(og_status)
    end

    def expect_update(appt, og_status, new_status, updator_id, updator_kind, target_update_status = nil)
      Sidekiq::Worker.clear_all
      expect {
        appt.record_status_update(new_status: new_status, updator_id: updator_id, updator_kind: updator_kind)
      }.to change(AppointmentUpdate, :count).by 1
      expect(LocationAppointmentsQueueWorker.jobs.count).to eq 1

      appointment_update = AppointmentUpdate.last
      expect(appointment_update.appointment_id).to eq appt.id
      expect(appointment_update.user_id).to eq updator_id
      expect(appointment_update.creator_kind).to eq updator_kind
      expect(appointment_update.status).to eq new_status

      appt.reload
      if appointment_update.update_only_status?
        expect(appt.status).to eq(target_update_status || og_status)
      else
        expect(appt.status).to eq(target_update_status || new_status)
      end

      appointment_update # return appointment_update for further tests, if desired
    end

    context "no_user" do
      let(:updator_kind) { "no_user" }
      it "does not record on_deck update" do
        expect_no_update(appointment, og_status, new_status, updator_id, updator_kind)
      end
      context "on_deck" do
        let(:og_status) { "on_deck" }
        let(:new_status) { "waiting" }
        it "does not record waiting update" do
          expect_no_update(appointment, og_status, new_status, updator_id, updator_kind)
        end
      end
      context "new_status being_helped" do
        let(:new_status) { "being_helped" }
        it "updates" do
          expect_update(appointment, og_status, new_status, updator_id, updator_kind)
        end
      end
      context "status being_helped" do
        let(:og_status) { "being_helped" }
        let(:new_status) { "waiting" }
        it "does not record on_deck update" do
          expect_no_update(appointment, og_status, new_status, updator_id, updator_kind)
        end
      end
    end
    context "signed_in_user" do
      let(:updator_kind) { "signed_in_user" }
      let(:updator_id) { FactoryBot.create(:user).id }
      it "does not record on_deck update" do
        expect_no_update(appointment, og_status, new_status, updator_id, updator_kind)
      end
      context "new_status abandoned" do
        let(:new_status) { "abandoned" }
        it "updates" do
          expect_update(appointment, og_status, new_status, updator_id, updator_kind)
        end
      end
    end
    context "organization_member" do
      let(:updator_kind) { "organization_member" }
      let(:updator_id) { 12 } # We aren't verifying that it's an org member in this method
      let(:appointment_on_deck) do
        FactoryBot.create(:appointment,
          organization: appointment.organization,
          location: appointment.location,
          status: "on_deck",
          line_number: 92)
      end
      context "new_status on_deck" do
        it "updates, order is changed" do
          appointment.reload
          appointment_on_deck.reload
          expect(appointment.line_number).to be < appointment_on_deck.line_number
          # Test that the way we order by status is correct
          expect(location.appointments.reorder(status: :desc).pluck(:id)).to eq([appointment_on_deck.id, appointment.id])
          expect(location.appointments.reorder(line_number: :asc).pluck(:id)).to eq([appointment.id, appointment_on_deck.id])
          expect(location.appointments.in_line.pluck(:id)).to eq([appointment_on_deck.id, appointment.id])
          expect_update(appointment, og_status, new_status, updator_id, updator_kind)
          expect(appointment.status).to eq "on_deck"
          location.reload
          expect(location.appointments.pluck(:status).uniq).to eq(["on_deck"])
          expect(location.appointments.in_line.pluck(:id)).to eq([appointment.id, appointment_on_deck.id])
        end
      end
    end
    context "queue_worker" do
      let(:updator_kind) { "queue_worker" }
      it "updates" do
        expect_update(appointment, og_status, new_status, updator_id, updator_kind)
        expect(appointment.on_deck?).to be_truthy
      end
    end
  end
end
