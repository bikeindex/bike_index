class InputNormalizer
  class << self
    delegate :boolean, :string, :present_or_false?, :sanitize, :regex_escape, to: "BinxUtils::InputNormalizer"
  end
end
