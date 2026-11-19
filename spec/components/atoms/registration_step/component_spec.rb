require "rails_helper"

RSpec.describe Atoms::RegistrationStep::Component, type: :component do
  let(:origin) { "register_flow" }
  let(:extra_params) { {} }
  let(:bike_params) { {owner_email: "owner@example.com", manufacturer_id: 12} }
  let(:b_param) { BParam.create(origin:, params: {bike: bike_params}.merge(extra_params).as_json) }
  let(:component) { render_inline(described_class.new(b_param:)) }

  it "renders the step" do
    expect(component).to have_text("Step 2")
  end

  context "not from the register flow" do
    let(:origin) { "api_v3" }

    it "renders nothing" do
      expect(component.to_html).to eq ""
    end
  end

  context "with the details entered, awaiting the email" do
    let(:extra_params) { {details_completed: true} }

    it "renders awaiting confirmation" do
      expect(component).to have_text("Awaiting email confirmation")
    end

    context "with a bike" do
      before { b_param.update(created_bike_id: 42) }

      it "renders finished" do
        expect(component).to have_text("Finished")
      end
    end
  end

  context "partway through an organization's rules" do
    let(:organization) { FactoryBot.create(:organization) }
    let(:course) { FactoryBot.create(:education_course_active, :with_pages, organization:) }
    let(:bike_params) { super().merge(cycle_type: "e-scooter", creation_organization_id: organization.id) }
    let(:extra_params) { {details_completed: true} }
    before do
      BikeServices::Register.acknowledge_page(b_param, course.education_course_pages.first, checked: %w[1 1])
    end

    it "renders the education page" do
      expect(component).to have_text("Education page 2")
    end
  end
end
