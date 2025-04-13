module SimpleNameable
  extend ActiveSupport::Concern

  def simple_name
    name&.gsub(/\s?\([^)]*\)/i, "")
  end

  def secondary_name
    return unless name&.match?(/\(/)

    name.split("(").last.tr(")", "")
  end
end
