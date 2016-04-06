class BikeIndex.BikesNew extends BikeIndex
  constructor: ->
    console.log('NEWWWW')
    new BikeIndex.ManufacturersSelect('#bike_manufacturer_id', true)