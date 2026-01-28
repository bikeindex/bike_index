# frozen_string_literal: true

module UI::UserTextBlockDisplay
  class ComponentPreview < ApplicationComponentPreview
    def default
      render(UI::UserTextBlockDisplay::Component.new(text:))
    end

    private

    def text
      "Same jianbing pabst gorpcore pok pok tracklocross bike lyfe and love" \
      "\n\nhoodie seitan food truck palo santo, Tbh neutral milk hotel scenester " \
      "portland bikes and tallbikes and unicycles and banh mi." \
      "\nAll morn the loss of All City\nall hail the black market" \
      "\n\nTruffaut polaroid hammock you probably haven't heard of them. Plaid chartreuse austin cold-pressed bruh. Slow-carb tousled iPhone skateboard helvetica 3 wolf moon, hot chicken lyft pork belly solarpunk neutral milk hotel humblebrag taxidermy pinterest. Keytar synth photo booth keffiyeh, twee organic tumblr raw denim butcher DSA leggings YOLO skateboard praxis. PBR&B man braid shabby chic pitchfork. Fam gentrify sartorial gochujang, pop-up copper mug letterpress. You probably haven't heard of them raw denim venmo authentic poutine pok pok gluten-free solarpunk gochujang tattooed kitsch man braid mukbang marxism meditation." \
      "\n\nChurch-key gluten-free bitters forage asymmetrical, kogi wolf organic mustache. Kickstarter tilde swag flexitarian. Chartreuse lomo godard vibecession +1. Shoreditch blog master cleanse, iceland chillwave farm-to-table small batch." \
      "\n\nTry-hard coloring book farm-to-table, biodiesel gluten-free hot chicken blackbird spyplane tacos craft beer. Venmo try-hard green juice XOXO. Solarpunk hexagon swag viral, lumbersexual neutra kinfolk irony iPhone post-ironic celiac banjo before they sold out try-hard. Iceland sus taxidermy blackbird spyplane humblebrag bicycle rights pork belly iPhone brunch helvetica sustainable. 8-bit succulents biodiesel, cliche live-edge tonx viral blackbird spyplane leggings yes plz swag. Iceland single-origin coffee banjo taiyaki snackwave tbh biodiesel salvia. Narwhal cupping grailed, schlitz tumblr taxidermy yuccie."
    end
  end
end
