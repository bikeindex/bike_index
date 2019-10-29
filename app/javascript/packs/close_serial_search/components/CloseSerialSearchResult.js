/* eslint import/no-unresolved: 0 */

import React, { Fragment } from "react";

const t = BikeIndex.translator("bikes_search");

const CloseSerialSearchResult = ({bike}) => (
  <li className="bike-box-item">
    <ResultImage bike={bike}/>

    <div className="bike-information multi-attr-lists">
      <h5 className="title-link">
        <a href={bike.url} target="_blank">
          <strong>
            {
              bike.manufacturer_name === "unknown_brand"
                ? t(bike.manufacturer_name)
                : [bike.year, bike.manufacturer_name].filter(a => a).join(' ')
            }
          </strong> {bike.frame_model}
        </a>
      </h5>

      <ul className="attr-list">
        <li>
          <span className="attr-title">{t("color")}</span>
          {
            bike.frame_colors.length
              ? bike.frame_colors.join(", ")
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
        {<AbandonedOrStolenDateItem bike={bike}/>}
        {<LocationItem bike={bike}/>}
      </ul>
    </div>
  </li>
)

const AbandonedOrStolenDateItem = ({bike}) => {
  if (!bike.date_stolen) {
    return <li/>
  }

  return (
    <li>
      <span className="attr-title text-danger">
        {bike.stolen ? t("stolen") : t("abandoned") }
      </span>
      <span className="convertTime">{bike.date_stolen}</span>
    </li>
  )
}

const LocationItem = ({bike}) => {
  if (!bike.stolen_location) {
    return <li/>
  }

  return (
    <li>
      <span className="attr-title">{t("location")}</span>
      {bike.stolen_location}
    </li>
  )
}

const ResultImage = ({ bike }) => {
  if (!bike.thumb || bike.is_stock_img) {
    return (<a className="bike-list-image" target="_blank" href={bike.url}>
              <img src={window.bike_placeholder_image} className="no-image"/>
            </a>);
  }

  return (<a className="bike-list-image hover-expand" target="_blank" href={bike.url}>
            <img alt={bike.title} src={bike.thumb}></img>
          </a>);
}

export default CloseSerialSearchResult;
