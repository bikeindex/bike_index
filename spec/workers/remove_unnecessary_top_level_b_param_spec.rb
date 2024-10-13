# frozen_string_literal: true
require "rails_helper"

RSpec.describe RemoveUnnecessaryTopLevelBParam, type: :job do
  let(:instance) { described_class.new }

  let!(:b_param) { FactoryBot.create(:b_param, params: {bike: bike_params, test: true, propulsion_type_motorized: 'false'}) }
  let!(:b_param_null) { FactoryBot.create(:b_param, params: {bike: bike_params, test: nil, propulsion_type_motorized: nil}) }
  let(:bike_params) do
    {year: 2022,
     is_new: nil,
     is_pos: nil,
     is_bulk: nil,
     propulsion_type_slug: "foot-pedal"}
  end
  let!(:b_param_motorized) { FactoryBot.create(:b_param, params: {bike: bike_params, propulsion_type_motorized: true})}

  before do
    b_param.reload.update_column :params, {bike: bike_params, test: true, propulsion_type_motorized: 'false'}.as_json
    b_param_null.reload.update_column :params, {bike: bike_params, test: nil, propulsion_type_motorized: nil}
  end

  it "removes unnecessary cycle_type" do
    expect(b_param.reload.params.keys).to match_array(["bike", "test", "propulsion_type_motorized"])
    expect(b_param_null.reload.params.keys).to match_array(["bike", "test", "propulsion_type_motorized"])
    og_updated_at = b_param.updated_at
    instance.perform
    expect(b_param.reload.params.keys).to match_array(["bike", "test"])
    expect(b_param.updated_at).to eq og_updated_at
    expect(b_param_null.reload.params.keys).to match_array(["bike", "test"])
    expect(b_param_motorized.reload.params.keys).to match_array(["bike", "propulsion_type_motorized"])
  end
end
