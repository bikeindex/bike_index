# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Register::StepFinished::Component, type: :component do
  let(:component) { render_inline(described_class.new(b_param:, current_user: nil)) }
  let(:b_param) { FactoryBot.create(:b_param, params: {bike: bike_params}) }
  let(:bike_params) { {owner_email: "someone@bikeindex.org", cycle_type: "e-scooter"} }

  # What confirming is for depends on what the registration is - a theft's link opens
  # the report, an ordinary one's just finishes adding the bike
  describe "awaiting the confirmation email" do
    it "heads with the progress saved, and offers to finish adding it" do
      expect(component).to have_css("h1", text: "Progress saved")
      expect(component).to have_text("Finish adding your e-scooter to Bike Index")
      expect(component).to have_no_text("Finish reporting your stolen")
    end

    context "status_stolen" do
      let(:bike_params) { super().merge(status: "status_stolen") }

      it "offers to finish the report instead" do
        expect(component).to have_css("h1", text: "Progress saved")
        expect(component).to have_text("Finish reporting your stolen e-scooter")
        expect(component).to have_no_text("Finish adding your")
      end
    end
  end

  it "registers another without an organization, and doesn't offer impound details" do
    expect(component).to have_link("Register another vehicle", href: "/register/new")
    expect(component).to have_no_text("Add details about where you found")
  end

  %w[status_impounded status_abandoned unregistered_parking_notification].each do |status|
    context status do
      let(:bike_params) { super().merge(status:) }

      it "offers to add where it was found" do
        expect(component).to have_text("Add details about where you found the e-scooter")
      end
    end
  end

  # Once there's a bike, the card says what happened to it - a theft isn't a bike being
  # watched over, it's one already being looked for
  context "the bike exists" do
    let(:current_user) { FactoryBot.create(:user_confirmed, email: "someone@bikeindex.org") }
    let(:component) { render_inline(described_class.new(b_param:, current_user:)) }
    let(:b_param) do
      FactoryBot.create(:b_param, created_bike_id: bike.id, params: {bike: bike_params})
    end

    context "status_with_owner" do
      let(:bike) { FactoryBot.create(:bike, :with_ownership, owner_email: "someone@bikeindex.org") }

      it "says it's being watched over" do
        expect(component).to have_text("Registration complete!")
        expect(component).to have_text("We'll keep watch")
      end
    end

    # A find is waiting to be claimed rather than looked for, so the checklist a theft
    # ends on isn't its
    context "status_impounded" do
      let(:bike) { FactoryBot.create(:impounded_bike, :with_ownership, owner_email: "someone@bikeindex.org") }

      it "says it's listed as found, and who it's waiting for" do
        expect(component).to have_css("h1", text: "is listed as found on Bike Index")
        expect(component).to have_text("Its owner can find it here and claim it")
        # Not the registrant's to be watched over, and no checklist - it isn't lost
        expect(component).to have_no_text("We'll keep watch")
        expect(component).to have_no_css("ul.stolen-checklist")
      end
    end

    context "status_stolen" do
      let(:bike) { FactoryBot.create(:stolen_bike, :with_ownership, owner_email: "someone@bikeindex.org") }

      it "heads with the theft, and leaves the watching-over copy to a bike that isn't stolen" do
        expect(component).to have_css("h1", text: "is listed as stolen on Bike Index")
        expect(component).to have_no_text("Registration complete!")
        expect(component).to have_no_text("if it's ever reported stolen")
        # The heading says what happened, so nothing is repeated under it
        expect(component).to have_no_css("h1 + p")
        # No address on this stolen record, so there's no checklist to show yet
        expect(component).to have_no_css("ul.stolen-checklist")
      end

      # What getting it back takes - the same list the theft details page ends on. The
      # report step asks for a location, so a theft registered through this flow has one
      context "with the location the report asks for" do
        let(:bike) do
          FactoryBot.create(:stolen_bike_in_chicago, :with_ownership, owner_email: "someone@bikeindex.org")
        end

        it "renders the checklist, ticking off what the registration already did" do
          expect(component).to have_css("ul.stolen-checklist")
          expect(component).to have_text("Do these things for the best chance of getting it back")
          # Listing it and reporting the theft are what the flow just did
          done = component.css("li.completed-item").map { |li| li.text.squish }
          expect(done.first).to eq "✓ List bike on Bike Index"
          expect(done.any? { |text| text.include?("Report theft on Bike Index") }).to be_truthy
          # Still to do, so it links to where they're added
          expect(component).to have_link("a photo of your bike")
          expect(component).to have_link("your Police Report Number")
        end
      end
    end
  end

  context "registered with an organization" do
    let(:organization) { FactoryBot.create(:organization, short_name: "Brakebills") }
    let(:bike_params) { super().merge(creation_organization_id: organization.id) }

    it "carries the organization onto the next registration" do
      expect(component).to have_link("Register another vehicle",
        href: "/register/new?organization_id=#{organization.slug}")
    end
  end
end
