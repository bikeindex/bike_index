class StolenRecordDecorator < ApplicationDecorator 
  delegate_all

  def show_stolen_address
    [
      object.street,
      object.city,
      (object.state && object.state.abbreviation),
      object.zipcode,
      (object.country && object.country.name)
    ].reject(&:blank?).join(', ')
  end
end