require "rails_helper"

RSpec.shared_examples "geocodeable" do
  let(:model_sym) { subject.class.name.underscore.to_sym }
  let(:instance) { FactoryBot.create model_sym }

  describe "friendly assigning state and country" do
    let(:country) { Country.united_states }
    let!(:state) { State.create(name: "Wyoming", abbreviation: "WY", country_id: country.id) }
    let(:obj_with_strings) { subject.class.new(state: "wy", country: "USA") }
    let(:obj_with_objects) { subject.class.new(state: state, country_id: country.id) }
    it "assigns by strings and by object, doesn't explode when not found" do
      expect(obj_with_strings.country).to eq country
      expect(obj_with_strings.state).to eq state
      obj_with_strings.state = "wyoming"
      expect(obj_with_strings.state).to eq state

      expect(obj_with_objects.country).to eq country
      expect(obj_with_objects.state).to eq state
      # Doesn't explode when not found
      obj_with_objects.state = "Other state"
      expect(obj_with_objects.state).to be_blank
    end
  end
end
