module ShortIdable
  extend ActiveSupport::Concern

  module ClassMethods
    # Find by id, decoding a short_id (e.g. "r/21J-HW") when present.
    def find_id(id)
      find(ShortId.decode(name, id))
    end
  end

  # Prefixed alphanumeric alias for the id, e.g. "r/21J-HW"
  def short_id
    ShortId.encode(self.class.name, id)
  end
end
