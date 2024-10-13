# frozen_string_literal: true

class RemoveUnnecessaryTopLevelBParam < ApplicationWorker
  def perform
    b_params_with_key.each do |b_param|
      next if InputNormalizer.boolean(b_param.params["propulsion_type_motorized"])

      b_param.update_column :params, b_param.params.except("propulsion_type_motorized")
    end
  end

  def b_params_with_key
    BParam.where('params::jsonb ? :key', key: 'propulsion_type_motorized')
  end
end
