import React from 'react';
import PropTypes from 'prop-types';
import Loading from './Loading';
import BikeList from './BikeList';

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
        {serialResults.map(({
          serial, anchor, bikes, fuzzyBikes,
        }) => {
          const hasResults = bikes.length > 0 || fuzzyBikes.length > 0;
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

      {/* Fuzzy search button  */}
      {!fuzzySearching && (
        <div className="multiserial-fuzzy-box">
          <button
            type="submit"
            className="btn-primary"
            onClick={onFuzzySearch}
          >
            Include closely matching serials in results
          </button>
        </div>
      )}

      {/* Bike Results */}
      <div id="bikes_returned">
        {serialResults.map(({
          bikes, fuzzyBikes, serial, anchor,
        }) => {
          if (bikes.length === 0 && fuzzyBikes.length === 0) return;
          const id = anchor.slice(1);
          return (
            <div key={id} id={id} className="multiserial-results">
              <BikeList serial={serial} bikes={bikes} />

              {fuzzySearching && (
                <BikeList
                  serial={serial}
                  bikes={fuzzyBikes}
                  fuzzySearching={fuzzySearching}
                />
              )
              }
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
