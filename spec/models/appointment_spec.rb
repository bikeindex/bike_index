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
      expect(appointment.line_entry_timestamp).to be_within(1).of appointment.created_at.to_i
      # And it updates the queue
      expect do
        appointment.update(updated_at: Time.current)
      end.to change(LocationAppointmentsQueueWorker.jobs, :count).by 1
      expect(LocationAppointmentsQueueWorker.jobs.map { |j| j["args"] }.last.flatten).to eq([appointment.location_id])
    end
  end

  describe "line_ordered, move_behind, move_to_back" do
    let!(:appt1) { FactoryBot.create(:appointment, line_entry_timestamp: (Time.current - 45.minutes).to_i) }
    let(:organization) { appt1.organization }
    let(:location) { appt1.location }
    # Shuffle the order when they're actually created around a little bit
    let!(:appt4) { FactoryBot.create(:appointment, line_entry_timestamp: (Time.current - 10.minutes).to_i, organization: organization, location: location) }
    let!(:appt5) { FactoryBot.create(:appointment, line_entry_timestamp: (Time.current - 5.minutes).to_i, organization: organization, location: location) }
    let!(:appt3) { FactoryBot.create(:appointment, line_entry_timestamp: (Time.current - 20.minutes).to_i, organization: organization, location: location) }
    let!(:appt2) { FactoryBot.create(:appointment, line_entry_timestamp: (Time.current - 30.minutes).to_i, organization: organization, location: location) }
    let!(:appt6) { FactoryBot.create(:appointment, line_entry_timestamp: (Time.current - 1.hour).to_i, organization: organization, location: location, status: "being_helped") }
    it "sorts by line_entry_timestamp" do
      location.reload
      expect(location.appointments.in_line.pluck(:id)).to eq([appt1.id, appt2.id, appt3.id, appt4.id, appt5.id])
      # Different than default ordering
      expect(Appointment.pluck(:id)).to_not eq(Appointment.line_ordered.pluck(:id))

      appt2.move_behind(appt4)
      expect(Appointment.line_ordered.pluck(:id)).to eq([appt6.id, appt1.id, appt3.id, appt4.id, appt2.id, appt5.id])

      # Doing it again doesn't change anything
      appt2.move_behind(appt4)
      expect(Appointment.line_ordered.pluck(:id)).to eq([appt6.id, appt1.id, appt3.id, appt4.id, appt2.id, appt5.id])
      # nil puts in front of line
      expect(location.appointments.in_line.on_deck.first).to be_blank
      appt3.move_ahead(location.appointments.in_line.on_deck.first) # this is an example of how we use it
      expect(Appointment.line_ordered.pluck(:id)).to eq([appt6.id, appt3.id, appt1.id, appt4.id, appt2.id, appt5.id])

      # Puts it ahead
      appt4.move_ahead(appt5)
      expect(Appointment.in_line.pluck(:id)).to eq([appt3.id, appt1.id, appt2.id, appt4.id, appt5.id])

      # nil puts in front of in_line
      appt4.move_ahead(location.appointments.in_line.on_deck.first)
      expect(Appointment.line_ordered.pluck(:id)).to eq([appt6.id, appt4.id, appt3.id, appt1.id, appt2.id, appt5.id])
    end
  end

  describe "record_status_update" do
    let!(:appointment) { FactoryBot.create(:appointment, status: og_status, line_entry_timestamp: (Time.current - 30.minutes).to_i) }
    let(:location) { appointment.location }
    let(:og_status) { "waiting" }
    let(:new_status) { "on_deck" }

    def expect_no_update(appt, og_status, new_status, updator_id, updator_type)
      Sidekiq::Worker.clear_all
      expect do
        result = appt.record_status_update(new_status: new_status, updator_id: updator_id, updator_type: updator_type)
        expect(result).to be_blank
      end.to_not change(AppointmentUpdate, :count)
      expect(LocationAppointmentsQueueWorker.jobs.count).to eq 0
      appt.reload
      expect(appt.status).to eq(og_status)
    end

    def expect_update(appt, og_status, new_status, updator_id, updator_type, target_update_status = nil)
      Sidekiq::Worker.clear_all
      expect do
        appt.record_status_update(new_status: new_status, updator_id: updator_id, updator_type: updator_type)
      end.to change(AppointmentUpdate, :count).by 1
      expect(LocationAppointmentsQueueWorker.jobs.count).to eq 1

      appointment_update = AppointmentUpdate.last
      expect(appointment_update.appointment_id).to eq appt.id
      expect(appointment_update.user_id).to eq updator_id
      expect(appointment_update.creator_type).to eq updator_type
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
      let(:updator_type) { "no_user" }
      let(:updator_id) { nil }
      it "does not record on_deck update" do
        expect_no_update(appointment, og_status, new_status, updator_id, updator_type)
      end
      context "new_status being_helped" do
        let(:new_status) { "being_helped" }
        it "updates" do
          expect_update(appointment, og_status, new_status, updator_id, updator_type)
        end
      end
      context "status being_helped" do
        let(:og_status) { "being_helped" }
        let(:new_status) { "waiting" }
        it "does not record on_deck update" do
          expect_no_update(appointment, og_status, new_status, updator_id, updator_type)
        end
      end
    end
    context "signed_in_user" do
      let(:updator_type) { "signed_in_user" }
      let(:updator_id) { FactoryBot.create(:user).id }
      it "does not record on_deck update" do
        expect_no_update(appointment, og_status, new_status, updator_id, updator_type)
      end
      context "new_status abandoned" do
        let(:new_status) { "abandoned" }
        it "updates" do
          expect_update(appointment, og_status, new_status, updator_id, updator_type)
        end
      end
    end
    context "organization_member" do
      let(:updator_type) { "organization_member" }
      let(:updator_id) { 12 } # We aren't verifying that it's an org member in this method
      let(:appointment_on_deck) do
        FactoryBot.create(:appointment,
                          organization: appointment.organization,
                          location: appointment.location,
                          status: "on_deck",
                          line_entry_timestamp: (Time.current - 1.hour).to_i)
      end
      context "new_status on_deck" do
        it "updates and moves to front of the queue" do
          appointment.reload
          appointment_on_deck.reload
          expect(appointment_on_deck.line_entry_timestamp).to be < appointment.line_entry_timestamp
          expect_update(appointment, og_status, new_status, updator_id, updator_type)
          # Because we've reordered
          expect(appointment_on_deck.line_entry_timestamp).to be > appointment.line_entry_timestamp
          location.reload
          expect(location.appointments.in_line.pluck(:id)).to eq([appointment.id, appointment_on_deck.id])
        end
      end
      context "failed_to_find" do
        let(:new_status) { "failed_to_find" }
        it "updates and moves to front of the queue" do
          expect(appointment.after_failed_to_find_removal_count).to eq 2
          expect(appointment_on_deck.line_entry_timestamp).to be < appointment.line_entry_timestamp
          # NOTE: Passing appointment_on_deck, not appointment
          appointment_update = expect_update(appointment_on_deck, og_status, new_status, updator_id, updator_type, "waiting")
          # Because we've reordered!
          appointment.reload
          appointment_on_deck.reload
          expect(appointment_on_deck.failed_to_find_attempts.pluck(:id)).to eq([appointment_update.id])
          expect(appointment_on_deck.line_entry_timestamp).to be > appointment.line_entry_timestamp
          location.reload
          expect(location.appointments.in_line.pluck(:id)).to eq([appointment.id, appointment_on_deck.id])
        end
      end
    end
  end
end
