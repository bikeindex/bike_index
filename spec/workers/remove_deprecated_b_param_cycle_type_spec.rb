# frozen_string_literal: true
require "rails_helper"

RSpec.describe RemoveDeprecatedBParamCycleType, type: :job do
  let(:instance) { described_class.new }

  let(:b_param) { FactoryBot.create(:b_param, params: {bike: bike_params, test: true}) }
  let(:bike_params) do
    {year: 2022,
     is_new: nil,
     is_pos: nil,
     is_bulk: nil,
     cycle_type: "bike",
     paint_id: 33577,
     send_email: true,
     frame_model: "ALLEZ",
     owner_email: "",
     no_duplicate: false,
     serial_number: "FAKE",
     handlebar_type: nil,
     manufacturer_id: 307,
     propulsion_type_slug: "foot-pedal",
     primary_frame_color_id: 1,
     creation_organization_id: 928}
  end
  let!(:b_param_tall_bike) { FactoryBot.create(:b_param, params: {bike: {owner_email: 's@s.org', cycle_type: 'tall-bike'}})}

  before { b_param.reload.update_column :params, {bike: bike_params, test: true}.as_json }

  it "removes unnecessary cycle_type" do
    expect(b_param.reload.bike).to match_hash_indifferently bike_params
    expect(b_param_tall_bike.reload.bike["cycle_type"]).to eq 'tall-bike'
    og_updated_at = b_param.updated_at
    instance.perform
    expect(b_param.reload.params["bike"]).to match_hash_indifferently bike_params.except(:cycle_type)
    expect(b_param.params.keys).to match_array(['test', 'bike'])
    expect(b_param.params['test']).to eq true
    expect(b_param.updated_at).to eq og_updated_at
    expect(b_param_tall_bike.reload.bike["cycle_type"]).to eq 'tall-bike'
  end
end
