class ParamsNormalizer
  def self.boolean(param = nil)
    return false if param.blank?
    ActiveRecord::Type::Boolean.new.cast(param.to_s.strip)
  end

  def self.present_or_false?(val)
    val.to_s.present?
  end

  def self.strip_or_nil_if_blank(val)
    val.present? ? val.strip : nil
  end

  def self.sanitize(str)
    Rails::Html::FullSanitizer.new.sanitize(str)&.strip
  end
end
