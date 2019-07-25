class BikeCodeBatch < ActiveRecord::Base
  belongs_to :user # Creator of the batch
  belongs_to :organization
  has_many :bike_codes

  def min_code_integer; bike_codes.minimum(:code_integer) || 0 end

  def max_code_integer; bike_codes.maximum(:code_integer) || 0 end

  def create_codes(number_to_create, initial_code_integer: nil, kind: "sticker")
    raise "Prefix required to create sequential codes!" unless prefix.present?
    initial_code_integer ||= max_code_integer
    initial_code_integer += 1 if bike_codes.where(code_integer: initial_code_integer).present?
    clength = code_number_length_or_default # Assign so it isn't recalculated in loop
    number_to_create.times do |i|
      code_integer_with_padding = (i + initial_code_integer).to_s.rjust(clength, "0")
      bike_codes.create!(organization: organization,
                         kind: kind,
                         code: prefix + code_integer_with_padding)
    end
    update_attributes(updated_at: Time.current) # Bump
  end

  def code_number_length_or_default
    return code_number_length if code_number_length.present?
    # minimum of 4. Return a larger number if there's a larger code in the batch
    max_code_integer.to_s.length > 4 ? max_code_integer.to_s.length : 4
  end
end
