import React from 'react';
import PropTypes from 'prop-types';
import Loading from './Loading';

const SearchResults = ({ serialResults, loading }) => (loading ? (
  <Loading />
) : (
  serialResults && (
  <section id="ms_search_section">
    <span className="padded" />
    <div className="multiserial-response">
      <h2>Multi serial search results</h2>

      <ul id="serials_submitted" className="multiserials-list">
        {serialResults.map(({ serial, bikes }) => (
          <li
            key={serial}
            className={bikes.length === 0 && 'ms-nomatch'}
            name={serial}
          >
            {serial}
          </li>
        ))}
      </ul>
    </div>
  </section>
  )
));

SearchResults.propTypes = {
  serialResults: PropTypes.arrayOf(PropTypes.object),
  loading: PropTypes.bool,
};

export default SearchResults;
