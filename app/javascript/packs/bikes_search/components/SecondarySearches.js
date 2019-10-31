/* eslint import/no-unresolved: 0 */

import React, { Fragment, Component } from "react";

import BikeSearch from "./BikeSearch";
import BikeSearchResult from "./BikeSearchResult";
import ExternalRegistrySearchResult from "./ExternalRegistrySearchResult";

import honeybadger from "../../utils/honeybadger";
import api from "../../api";

const t = window.BikeIndex.translator("bikes_search");

const queries = ({ interpretedParams }) => {
  const serialNumbers =
        interpretedParams
        .raw_serial
        .split(/\s+|,/)
        .map(s => s.trim())
        .filter(s => (/^\w+$/).test(s));

  return serialNumbers.map(serial => ({...interpretedParams, serial: serial, raw_serial: serial}))
}

const MultipleSerialSearchHeader = ({ serial, queriesCount }) =>
      (queriesCount === 1)
      ? <Fragment/>
      : (<h2 className="secondary-matches">
          {t("serial_search", { serial })}
        </h2>)

const SecondarySearches = ({ interpretedParams }) => (
  !interpretedParams.serial
    ? <Fragment/>
    : <Fragment>
      {
        queries({ interpretedParams }).map((params, i, allQueries) =>
            (
              <Fragment key={params.serial}>
                <MultipleSerialSearchHeader
                  serial={params.serial}
                  queriesCount={allQueries.length}
                />
                <BikeSearch
                  fetchBikes={api.fetchPartialMatchSearch}
                  searchName="search_serials_containing"
                  resultComponent={BikeSearchResult}
                  interpretedParams={params}
                  t={window.BikeIndex.translator("bikes_search.search_serials_containing")}
                />
                <BikeSearch
                  fetchBikes={api.fetchSerialCloseSearch}
                  searchName="search_similar_serials"
                  resultComponent={BikeSearchResult}
                  interpretedParams={params}
                  t={window.BikeIndex.translator("bikes_search.search_similar_serials")}
                />
                <BikeSearch
                  fetchBikes={api.fetchSerialExternalSearch}
                  searchName="search_external_registries"
                  resultComponent={ExternalRegistrySearchResult}
                  interpretedParams={params}
                  t={window.BikeIndex.translator("bikes_search.search_external_registries")}
                />
              </Fragment>
            )
          )
        }
      </Fragment>
  )

export default SecondarySearches;
