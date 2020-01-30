class ActionController::Parameters
  # DEPRECATION WARNING: #to_hash unexpectedly ignores parameter filtering, and
  # will change to enforce it in Rails 5.1.
  # Enable # `raise_on_unfiltered_parameters` to respect parameter filtering, which is the
  # default in new applications.
  # For the existing deprecated behaviour, call #to_unsafe_h instead.

  def to_hash
    to_unsafe_h
  end
end
