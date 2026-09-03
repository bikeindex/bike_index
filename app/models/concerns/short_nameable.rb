module ShortNameable
  extend ActiveSupport::Concern

  def short_name
    name&.gsub(/\s?\(.*/i, "")
  end

  def secondary_name
    return unless name&.match?(/\(/)

    name.split("(").last.gsub(/\).*/i, "")
  end
end
