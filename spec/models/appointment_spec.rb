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
      expect(appointment.appointment_at).to be_within(1).of appointment.created_at
      expect(appointment.ticket_number).to be_blank
      expect(appointment.position_in_line).to be_blank
      # And it updates the queue
      expect do
        appointment.update(updated_at: Time.current)
      end.to change(LocationAppointmentsQueueWorker.jobs, :count).by 1
      expect(LocationAppointmentsQueueWorker.jobs.map { |j| j["args"] }.last.flatten).to eq([appointment.location_id])
    end
  end

  describe "for_user_attrs & matches_user_attrs?" do
    it "fails unless passed one arg" do
      expect do
        Appointment.for_user_attrs(email: "beth@STuff.com", user_id: 12)
      end.to raise_error(/one/)
      expect do
        Appointment.for_user_attrs(email: " ")
      end.to raise_error(/one/)
    end
    context "with appointments" do
      let(:user) { FactoryBot.create(:user_confirmed, email: "beth@stuff.com") }
      let(:appt1) { FactoryBot.create(:appointment, email: "BETH@stuff.com") }
      let(:organization) { appt1.organization }
      let(:location) { appt1.location }
      let!(:appt2) { FactoryBot.create(:appointment, organization: organization, location: location, user: user) }
      let!(:appt3) { FactoryBot.create(:appointment, email: "elizabeth@EXAMPLE.com ", creation_ip: "108.000.215.126") }
      it "associates and finds them, etc" do
        # Create secondary email after the fact, so that the user isn't associated
        FactoryBot.create(:user_email, user: user, email: "elizabeth@example.com")
        appt1.reload
        appt2.reload
        appt3.reload
        expect(appt1.user_id).to be_blank
        expect(appt2.user_id).to eq user.id
        expect(appt3.user_id).to be_blank
        expect(appt3.creation_ip.to_s).to eq "108.000.215.126"

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

  context "existing appointments" do
    let(:appt1_status) { "waiting" }
    let(:appt3_status) { "waiting" }
    let!(:appt1) { FactoryBot.create(:appointment, status: appt1_status, ticket_number: 45) }
    let(:organization) { appt1.organization }
    let(:location) { appt1.location }
    # Shuffle the order when they're actually created around a little bit
    let!(:appt4) { FactoryBot.create(:appointment, ticket_number: 48, organization: organization, location: location) }
    let!(:appt5) { FactoryBot.create(:appointment, ticket_number: 49, organization: organization, location: location) }
    let!(:appt3) { FactoryBot.create(:appointment, status: appt3_status, ticket_number: 47, organization: organization, location: location) }
    let!(:appt2) { FactoryBot.create(:appointment, ticket_number: 46, organization: organization, location: location) }
    let!(:appt6) { FactoryBot.create(:appointment, status: "being_helped", ticket_number: 44, organization: organization, location: location) }
    describe "line_ordered, move_behind, move_to_back" do
      it "sorts by position_in_line" do
        location.reload
        expect(location.appointments.in_line.pluck(:id)).to eq([appt1.id, appt2.id, appt3.id, appt4.id, appt5.id])
        # Different than default ordering
        expect(Appointment.pluck(:id)).to_not eq(Appointment.line_ordered.pluck(:id))

        appt2.move_behind(appt4)
        expect(Appointment.line_ordered.pluck(:id)).to eq([appt1.id, appt3.id, appt4.id, appt2.id, appt5.id, appt6.id])

        # Doing it again doesn't change anything
        appt2.move_behind(appt4)
        expect(Appointment.in_line.pluck(:id)).to eq([appt1.id, appt3.id, appt4.id, appt2.id, appt5.id])
        # nil puts in front of line
        expect(location.appointments.in_line.on_deck.first).to be_blank
        appt3.move_ahead(location.appointments.in_line.on_deck.first) # this is an example of how we use it
        expect(Appointment.line_ordered.pluck(:id)).to eq([appt3.id, appt1.id, appt4.id, appt2.id, appt5.id, appt6.id])

        # Puts it ahead
        appt4.move_ahead(appt5)
        expect(Appointment.in_line.pluck(:id)).to eq([appt3.id, appt1.id, appt2.id, appt4.id, appt5.id])

        # nil puts in front of in_line
        appt4.move_ahead(location.appointments.in_line.on_deck.first)
        expect(Appointment.line_ordered.pluck(:id)).to eq([appt4.id, appt3.id, appt1.id, appt2.id, appt5.id, appt6.id])
      end
    end
    describe "update_and_move_for_failed_to_find" do
      let(:appt1_status) { "on_deck" }
      let(:appt3_status) { "paging" }
      it "puts behind the last on deck twice, then to the back of the line, then removes" do
        # Line ordered first orders by the status priority, then by position_in_line
        expect(Appointment.line_ordered.pluck(:id)).to eq([appt3.id, appt1.id, appt2.id, appt4.id, appt5.id, appt6.id])
        expect(Appointment.in_line.pluck(:id)).to eq([appt3.id, appt1.id, appt2.id, appt4.id, appt5.id])
        expect(Appointment.paging_or_on_deck.pluck(:id)).to eq([appt3.id, appt1.id])

        expect(appt6.after_failed_to_find_removal_count).to eq 2
        # it's possible to failed_to_find something not in line
        expect do
          appt6.record_status_update(new_status: "failed_to_find", updator_id: 12, updator_kind: "organization_member")
        end.to change(AppointmentUpdate, :count).by 1
        appt6.reload # try to ward off flaky behavior
        expect(appt6.status).to eq "waiting"
        appointment_update1 = appt6.appointment_updates.last
        expect(appointment_update1.creator_kind).to eq "organization_member"
        expect(appointment_update1.user_id).to eq 12
        expect(appointment_update1.status).to eq "failed_to_find"
        expect(Appointment.in_line.pluck(:id)).to eq([appt3.id, appt1.id, appt2.id, appt6.id, appt4.id, appt5.id])
        # doing it for another appt puts that appt one back in the waiting queue
        expect do
          appt3.record_status_update(new_status: "failed_to_find", updator_kind: "queue_worker")
        end.to change(AppointmentUpdate, :count).by 1
        appt3.reload
        expect(appt3.status).to eq "waiting"
        appointment_update2 = appt3.appointment_updates.last
        expect(appointment_update2.creator_kind).to eq "queue_worker"
        expect(appointment_update2.user_id).to be_blank
        expect(appointment_update2.status).to eq "failed_to_find"
        expect(Appointment.line_ordered.pluck(:id)).to eq([appt1.id, appt2.id, appt6.id, appt3.id, appt4.id, appt5.id])
        # Final warning for 6, puts it in back of the waiting queue
        expect do
          appt6.record_status_update(new_status: "failed_to_find", updator_kind: "queue_worker")
        end.to change(AppointmentUpdate, :count).by 1
        appt6.reload # try to ward off flaky behavior
        expect(appt6.status).to eq "waiting"
        appointment_update4 = appt6.appointment_updates.last
        expect(appointment_update4.creator_kind).to eq "queue_worker"
        expect(appointment_update4.user_id).to be_blank
        expect(appointment_update4.status).to eq "failed_to_find"
        expect(Appointment.in_line.pluck(:id)).to eq([appt1.id, appt2.id, appt3.id, appt4.id, appt5.id, appt6.id])
        # It Removes 6
        expect do
          appt6.record_status_update(new_status: "failed_to_find", updator_kind: "organization_member", updator_id: 3333)
        end.to change(AppointmentUpdate, :count).by 1
        appt6.reload # try to ward off flaky behavior
        expect(appt6.status).to eq "removed"
        appointment_update5 = appt6.appointment_updates.last
        expect(appointment_update5.creator_kind).to eq "organization_member"
        expect(appointment_update5.user_id).to eq 3333
        expect(appointment_update5.status).to eq "failed_to_find"
        expect(Appointment.in_line.pluck(:id)).to eq([appt1.id, appt2.id, appt3.id, appt4.id, appt5.id])
      end
    end
  end

  describe "record_status_update" do
    let!(:appointment) { FactoryBot.create(:appointment, status: og_status, ticket_number: 20) }
    let(:location) { appointment.location }
    let(:og_status) { "waiting" }
    let(:new_status) { "on_deck" }
    let(:updator_id) { nil }

    def expect_no_update(appt, og_status, new_status, updator_id, updator_kind)
      Sidekiq::Worker.clear_all
      expect do
        result = appt.record_status_update(new_status: new_status, updator_id: updator_id, updator_kind: updator_kind)
        expect(result).to be_blank
      end.to_not change(AppointmentUpdate, :count)
      expect(LocationAppointmentsQueueWorker.jobs.count).to eq 0
      appt.reload
      expect(appt.status).to eq(og_status)
    end

    def expect_update(appt, og_status, new_status, updator_id, updator_kind, target_update_status = nil)
      Sidekiq::Worker.clear_all
      expect do
        appt.record_status_update(new_status: new_status, updator_id: updator_id, updator_kind: updator_kind)
      end.to change(AppointmentUpdate, :count).by 1
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
                          ticket_number: 2)
      end
      context "new_status on_deck" do
        it "updates and doesn't move to front of the queue" do
          appointment.reload
          appointment_on_deck.reload
          expect(appointment_on_deck.position_in_line).to be < appointment.position_in_line
          expect_update(appointment, og_status, new_status, updator_id, updator_kind)
          location.reload
          expect(location.appointments.in_line.pluck(:id)).to eq([appointment_on_deck.id, appointment.id])
        end
      end
      context "failed_to_find" do
        let(:new_status) { "failed_to_find" }
        it "updates and moves to front of the queue" do
          expect(appointment.after_failed_to_find_removal_count).to eq 2
          expect(appointment_on_deck.position_in_line).to be < appointment.position_in_line
          # NOTE: Passing appointment_on_deck, not appointment
          appointment_update = expect_update(appointment_on_deck, og_status, new_status, updator_id, updator_kind, "waiting")
          # Because we've reordered!
          appointment.reload
          appointment_on_deck.reload
          expect(appointment_on_deck.failed_to_find_attempts.pluck(:id)).to eq([appointment_update.id])
          expect(appointment_on_deck.position_in_line).to be > appointment.position_in_line
          location.reload
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
