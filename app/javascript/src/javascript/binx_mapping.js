import * as log from "loglevel";
import _ from "lodash";

window.BinxMapping = class BinxMapping {
  // The page instance of this class is modified to store the current list of points for rendering
  constructor(kind) {
    this.kind = kind;
    this.markerPointsToRender = [];
    this.markersRendered = [];
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
    binxMapping.zoom = zoom;
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

  fitMap() {
    let bounds = new google.maps.LatLngBounds();
    // Fit to markers
    for (let marker of Array.from(binxMapping.markersRendered)) {
      if (marker) {
        bounds.extend(marker.getPosition());
      }
    }
    binxMap.fitBounds(bounds);

    // Finish rendering map, then check - if too zoomed in (e.g. on one point), zoom out
    window.setTimeout(function() {
      if (binxMap.zoom > 16) {
        binxMap.setZoom(16);
      }
    }, 500);
  }

  clearMarkers() {
    if (!binxMapping.markersRendered) {
      binxMapping.markersRendered = [];
    }

    if (window.infoWindow != null) {
      window.infoWindow.close();
    }
    // Useful when the page reloads without fully reloading
    if (binxMapping.markersRendered.length) {
      for (let i of Array.from(binxMapping.markersRendered)) {
        i != null && i.setMap(null);
      }
    }
    // Ids make sure we aren't double rendering
    return (window.renderedMarkerIds = []);
  }

  renderMarker(point) {
    let popupContent = "";
    if (binxMapping.kind == "geolocated_messages") {
      popupContent = binxAppOrgMessages.geolocatedMessageMapPopup(point);
    } else {
      log.warn(binxMapping.kind);
      popupContent = "Missing template!";
    }
    window.infoWindow.setContent(popupContent);
    // Ensure things are rendered before setting times, pause for a hot sec
    window.setTimeout(() => binxApp.localizeTimes(), 50);
  }

  addMarkers(fit_map) {
    log.warn(`adding markers - fit_map: ${fit_map}`);
    while (binxMapping.markerPointsToRender.length > 0) {
      let point = binxMapping.markerPointsToRender.shift();
      let markerId = point.id;
      if (_.find(binxMapping.markersRendered, ["id", point.id])) {
        log.warn(`already rendered point: ${point.id}`);
      } else {
        let marker = new google.maps.Marker({
          position: new google.maps.LatLng(point.lat, point.lng),
          map: window.binxMap,
          binxId: markerId
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
        binxMapping.markersRendered.push(marker);
      }
    }
    // If we're suppose to fit the map to the markers - and if there are markers that have been rendered - fit it
    if (fit_map == true && binxMapping.markersRendered.length > 0) {
      binxMapping.fitMap();
    }
  }
};
