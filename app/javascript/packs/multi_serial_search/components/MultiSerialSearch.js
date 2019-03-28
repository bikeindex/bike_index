/* eslint import/no-unresolved: 0 */

import React, { useState, Fragment } from 'react';
import searchIcon from 'images/stolen/search';
import SearchResults from './SearchResults';
import { fetchSerialResults } from '../api';

const MultiSerialSearch = () => {
  const [serialResults, setSerialResults] = useState(null);
  const [searchTokens, setSearchTokens] = useState('');
  const [visibility, setVisibility] = useState(false);
  const [loading, setLoading] = useState(false);

  const onSearchSerials = async e => {
    e.preventDefault();
    if (!searchTokens) return;

    setLoading(true);
    const tokens = searchTokens.split(/,|\n/);
    const uniqSerials = [...new Set(tokens)];

    /*
      parallelized Promise.all request for all serials
    */
    const all = await Promise.all(
      uniqSerials.map(serial => fetchSerialResults(serial)),
    );
    const results = all.map(({ bikes }, index) => {
      const serial = uniqSerials[index];
      return {
        bikes,
        serial,
        anchor: `#${encodeURI(serial)}`,
      };
    });
    setSerialResults(results);
    setLoading(false);
  };

  const toggleVisibility = e => {
    e.preventDefault();
    setVisibility(!visibility);
  };

  const onChangeSearchTokens = e => {
    e.preventDefault();
    const tokens = e.target.value;
    setSearchTokens(tokens);
  };

  return (
    <Fragment>
      <h4 className="multi-search-toggle">
        <a href="" onClick={toggleVisibility}>
          {visibility ? 'Hide' : 'Show'} Multiple Serial Search
        </a>
      </h4>

      {visibility && (
        <div className="multiserial-form">
          {/* Form  */}
          <span className="padded" />
          <h3>Multiple Serial Search</h3>
          <textarea
            value={searchTokens}
            className="form-control"
            onChange={onChangeSearchTokens}
            placeholder="Enter multiple serial numbers. Separate them with commas or new lines"
          />
          <button
            type="submit"
            className="sbrbtn"
            disabled={loading}
            onClick={onSearchSerials}
          >
            <img alt="search" src={searchIcon} />
          </button>

          {/* Search Results */}
          <SearchResults serialResults={serialResults} loading={loading} />
        </div>
      )}
    </Fragment>
  );
};

export default MultiSerialSearch;

/*
  TODO:
    - Close matching serials
    - Search button style
    - jQuery animations
*/
