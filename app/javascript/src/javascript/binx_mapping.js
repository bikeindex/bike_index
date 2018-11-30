import * as log from "loglevel";

window.BinxMapping = class BinxMapping {
  // The page instance of this class is modified to store the current list of points for rendering
  constructor(kind) {
    this.kind = kind;
    this.markerPointsToRender = [];
  }

  loadMap(callback) {
    if (window.googleMapInjected || this.googleMapsLoaded()) {
      return true;
    }
    // Add google maps script
    var js_file = document.createElement("script");
    js_file.type = "text/javascript";
    js_file.src = `https://maps.googleapis.com/maps/api/js?callback=${callback}&key=${
      window.pageInfo.google_maps_key
    }`;
    document.getElementsByTagName("head")[0].appendChild(js_file);
    window.googleMapInjected = true;
  }

  render(lat, lng, zoom = null) {
    if (zoom == null) {
      zoom = 13;
    }
    var myOptions = {
      zoom: zoom,
      center: new google.maps.LatLng(lat, lng),
      mapTypeId: google.maps.MapTypeId.ROADMAP
    };
    if (!window.infoWindow) {
      window.infoWindow = new google.maps.InfoWindow();
    }
    window.binxMap = new google.maps.Map(
      document.getElementById("map"),
      myOptions
    );
  }

  googleMapsLoaded() {
    return typeof google === "object" && typeof google.maps === "object";
  }

  renderMarker(point) {
    let popupContent = "";
    if (binxMapping.kind == "geolocated_messages") {
      popupContent = binxAppOrgMessages.geolocatedMapPopup(point);
    } else {
      log.warn(binxMapping.kind);
      popupContent = "Missing template!";
    }
    window.infoWindow.setContent(popupContent);
    // Ensure things are rendered before setting times, pause for a hot sec
    window.setTimeout(() => binxApp.localizeTimes(), 50);
  }

  addMarkers() {
    while (binxMapping.markerPointsToRender.length > 0) {
      let point = binxMapping.markerPointsToRender.shift();
      let markerId = point.id;
      let marker = new google.maps.Marker({
        position: new google.maps.LatLng(point.lat, point.lng),
        map: window.binxMap
      });

      google.maps.event.addListener(
        marker,
        "click",
        ((marker, markerId) =>
          function() {
            window.infoWindow.setContent("");
            window.infoWindow.open(window.binxMap, marker);
            return binxMapping.renderMarker(point);
          })(marker, markerId)
      );
    }
  }
};
