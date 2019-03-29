/* eslint jsx-a11y/anchor-has-content: 0 */

import React from 'react';
import PropTypes from 'prop-types';
import pluralize from 'pluralize';
import Loading from './Loading';

const SearchResults = ({
  serialResults, loading, onFuzzySearch, fuzzySearching,
}) => (loading ? (
  <Loading />
) : (
  serialResults && (
  <section id="ms_search_section">
    <span className="padded" />
    <div className="multiserial-response">
      <h2>Multi serial search results</h2>

      {/* Serial search chips */}
      <ul id="serials_submitted" className="multiserials-list">
        {serialResults.map(({ serial, bikes, anchor }) => {
          const hasResults = bikes && bikes.length > 0;
          return (
            <li
              key={serial}
              className={hasResults ? 'ms-match' : 'ms-nomatch'}
              name={serial}
            >
              {serial}
              {hasResults && (
                <a href={anchor} className="scroll-to-ref" />
              )}
            </li>
          );
        })}
      </ul>

      {/* Search result list per serial */}
      <div id="bikes_returned">
        {serialResults.map(({ serial, bikes, anchor }) => {
          if (bikes.length === 0) return;
          const resultsTitle = bikes.length > 19 ? 'First 20 of many' : bikes.length;
          return (
            <div id={anchor} className="multiserial-results">
              <div>
                <h3>
                  <span className="serial-text">{serial}</span>
                  {' - '}
                  {resultsTitle} {pluralize('results', bikes.length)}
                </h3>
                <ul>
                  {bikes.map(({ stolen, url, title }) => (
                    <li key={serial}>
                      {stolen && <span className="stolen-color">Stolen</span>}
                      {' '}
                      <a href={url} target="_blank" rel="noopener noreferrer">
                        {title}
                      </a>
                      <span className="serial-text">{serial}</span>
                    </li>
                  ))}
                </ul>
              </div>
            </div>
          );
        })}
      </div>

    </div>
  </section>
  )
));

SearchResults.propTypes = {
  serialResults: PropTypes.arrayOf(PropTypes.object),
  loading: PropTypes.bool,
  fuzzySearching: PropTypes.bool,
  onFuzzySearch: PropTypes.func,
};

export default SearchResults;
