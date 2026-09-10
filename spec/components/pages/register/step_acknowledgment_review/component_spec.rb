# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Register::StepAcknowledgmentReview::Component, type: :component do
  let(:organization) { FactoryBot.create(:organization) }
  let(:sequence) do
    FactoryBot.create(:registration_sequence_active, :with_pages, organization:,
      acknowledgment_text: "agree to all of it")
  end
  let(:current_user) { FactoryBot.create(:user_confirmed, name: "Filling It In") }
  let(:bike_params) { {owner_email: "someone-else@example.com", user_name:} }
  let(:b_param) { BParam.create(origin: "register_flow", params: {bike: bike_params}.as_json) }
  let(:steps) { BikeServices::Register.steps(b_param, sequence:) }

  describe "who is agreeing" do
    context "registered for someone else" do
      let(:user_name) { "Sally Rider" }

      it "names them, not the account filling the form in" do
        render_inline(described_class.new(b_param:, sequence:, steps:, current_user:))

        expect(page).to have_content("I, Sally Rider,")
        expect(page).to_not have_content("Filling It In")
      end
    end

    context "their own registration" do
      let(:user_name) { nil }
      let(:bike_params) { {owner_email: current_user.email} }

      it "falls back to the signed-in account - step 2 never asked for a name" do
        render_inline(described_class.new(b_param:, sequence:, steps:, current_user:))

        expect(page).to have_content("I, Filling It In,")
      end
    end

    context "anonymous, with no name given" do
      let(:user_name) { nil }

      it "falls back to the address the registration is going to" do
        render_inline(described_class.new(b_param:, sequence:, steps:, current_user: nil))

        expect(page).to have_content("I, someone-else@example.com,")
      end
    end
  end
end
