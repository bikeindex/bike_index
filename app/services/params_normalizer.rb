class ParamsNormalizer
  def self.boolean(param = nil)
    return false if param.blank?
    ActiveRecord::Type::Boolean.new.type_cast_from_database(param.to_s.strip)
  end
end
