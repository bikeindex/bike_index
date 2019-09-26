const bikeResponse = {
  bikes: [
    {
      id: 596985,
      title: '2017 Novara Strada',
      serial: 'U161K02722',
      manufacturer_name: 'Novara',
      frame_model: 'Strada',
      year: 2016,
      frame_colors: ['Red'],
      thumb: 'https://files.bikeindex.org/uploads/Pu/149821/small_20190320_212118.jpg',
      large_img: 'https://files.bikeindex.org/uploads/Pu/149821/large_20190320_212118.jpg',
      is_stock_img: false,
      stolen: true,
      stolen_location: 'Portland,OR,97202',
      date_stolen: 1553295600,
      frame_material: null,
      handlebar_type: 'Drop',
    },
  ],
};


const externalBikeResponse = {
  bikes: [
    {
      date_stolen: "2010-10-06",
      info_hash: {},
      description: null,
      frame_colors: ["Grijs"],
      frame_model: "Live",
      id: "2010027007",
      is_stock_img: true,
      large_img: "/assets/revised/bike_photo_placeholder-ff15adbd9bf89e10bf3cd2cd6c4e85e5d1056e50463ae722822493624db72e56.svg",
      location_found: null,
      manufacturer_name: "Batavus",
      external_id: "2010027007",
      registry_name: "stopheling.nl",
      registry_url: "https://www.stopheling.nl",
      serial: "BA6038224",
      source_name: "Politie Hollands Midden",
      source_unique_id: "90765",
      status: "Stolen",
      stolen: true,
      stolen_location: null,
      thumb: "/assets/revised/bike_photo_placeholder-ff15adbd9bf89e10bf3cd2cd6c4e85e5d1056e50463ae722822493624db72e56.svg",
      title: "Batavus Live",
      url: "https://www.stopheling.nl"
    }
  ]
};

export {
  bikeResponse,
  externalBikeResponse,
};
