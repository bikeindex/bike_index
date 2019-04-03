/* eslint import/no-unresolved: 0 */

import React, { useState, Fragment } from 'react';
import searchIcon from 'images/stolen/search';
import SearchResults from './SearchResults';
import { fetchSerialResults, fetchFuzzyResults } from '../api';
import honeybadger from '../../utils/honeybadger';

const MultiSerialSearch = () => {
  const [serialResults, setSerialResults] = useState(null);
  const [searchTokens, setSearchTokens] = useState('');
  const [visibility, setVisibility] = useState(false);
  const [loading, setLoading] = useState(false);
  const [fuzzySearching, setFuzzySearching] = useState(false);

  const handleEventErrors = error => {
    honeybadger.notify(error, { component: 'MultiSerialSearch' });
    setLoading(false);
  };

  const onSearchSerials = async () => {
    if (!searchTokens) return;
    setLoading(true);

    /*
      normalize the textarea input
    */
    const tokens = searchTokens
      .split(/,|\n/)
      .map(s => s.trim())
      .filter(s => s);
    const uniqSerials = [...new Set(tokens)];

    try {
      /*
        parallel request serials
      */
      const all = await Promise.all(
        uniqSerials.map(serial => fetchSerialResults(serial)),
      );
      const results = all.map(({ bikes }, index) => {
        const serial = uniqSerials[index];
        return {
          bikes,
          serial,
          fuzzyBikes: [],
          anchor: `#${encodeURI(serial)}`,
        };
      });
      setSerialResults(results);
      setFuzzySearching(false);
      setLoading(false);
    } catch (e) {
      handleEventErrors(e);
    }
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

  const onFuzzySearch = async () => {
    if (fuzzySearching) return;
    if (!serialResults) return;
    setLoading(true);

    try {
      /*
        parallel request fuzzy serials and merge
      */
      const fuzzyAll = await Promise.all(
        serialResults.map(({ serial }) => fetchFuzzyResults(serial)),
      );
      const updatedResults = fuzzyAll.map(({ bikes: fuzzyBikes }, index) => {
        const serialResult = serialResults[index];
        return Object.assign(serialResult, { fuzzyBikes });
      });
      setSerialResults(updatedResults);
      setFuzzySearching(true);
      setLoading(false);
    } catch (e) {
      handleEventErrors(e);
    }
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
          <SearchResults
            loading={loading}
            serialResults={serialResults}
            fuzzySearching={fuzzySearching}
            onFuzzySearch={onFuzzySearch}
          />
        </div>
      )}
    </Fragment>
  );
};

export default MultiSerialSearch;
