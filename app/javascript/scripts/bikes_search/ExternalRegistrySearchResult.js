/* eslint import/no-unresolved: 0 */

import React, { Fragment } from "react";
import _ from "lodash";
import lodashInflection from "lodash-inflection";

_.mixin(lodashInflection);

const t = BikeIndex.translator("bikes_search");

const ExternalRegistrySearchResult = ({ bike }) => (
  <li className="bike-box-item">
    <ResultImage bike={bike}/>

    <div className="bike-information">
      <h5 className="title-link">
        <a href={bike.url} target="_blank">
          <strong>
            {
              bike.manufacturer_name === "unknown_brand"
                ? t(bike.manufacturer_name)
                : _.titleize(bike.manufacturer_name)
            }
          </strong> {_.titleize(bike.frame_model)}
        </a>
      </h5>

      <ul className="attr-list">
        <li>
          <span className="attr-title">{t("color")}</span>
          {
            bike.frame_colors.length
              ? bike.frame_colors.map(c => _.titleize(c)).join(", ")
              : t("unknown")
          }
        </li>
        <li>
          <span className="attr-title">{t("serial")}</span>
          {
            bike.serial === "absent"
              ? t("absent")
              : bike.serial === "Hidden"
              ? t("hidden")
              : bike.serial
          }
        </li>
      </ul>

      <ul className="attr-list">
        <li>
          <span className="attr-title text-danger">
            {t(bike.status)}
          </span>
          <span className="convertTime">
            {bike.date_stolen}
          </span>
        </li>
        <li>
          <span className="attr-title">{t("registry")}</span>
          <a href={bike.registry_url} target="_blank">{bike.registry_name}</a>
        </li>
        <li>
          <span className="attr-title">{t("registry_id")}</span>
          {bike.external_id}
        </li>
        <li>
          <span className="attr-title">{t("location")}</span>
          {bike.stolen_location}
        </li>
      </ul>
    </div>
  </li>
)

const ResultImage = ({ bike }) => {
  const backgroundStyles = ({ thumb }) => ({
    backgroundSize: "contain",
    backgroundPosition: "left",
    backgroundRepeat: "no-repeat",
    backgroundImage: `url('${thumb}')`
  });

  if (bike.is_stock_img) {
    return (<a href={bike.url} className="bike-list-image" target="_blank">
              <img src={window.bike_placeholder_image} className="no-image" />
            </a>);
  }

  return (<a href={bike.url}
             style={backgroundStyles(bike)}
             data-img-src={bike.thumb}
             className="bike-list-image hover-expand"
             target="_blank"></a>);
}

export default ExternalRegistrySearchResult;
