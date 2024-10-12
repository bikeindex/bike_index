# frozen_string_literal: true

class RemoveDeprecatedBParamCycleType < ApplicationWorker
  def perform
    BParam.deprectated_cycle_type_bike.find_each do |b_param|
      b_param.update_column :params, new_params(b_param.params)
    end
  end

  def new_params(params)
    params["bike"].delete("cycle_type")
    params
  end
end
