/* eslint import/no-unresolved: 0 */

import React from 'react';
import { shallow, mount } from 'enzyme';
import toJson from 'enzyme-to-json';
import { bikeResponse } from 'helpers/bikes';
import { event } from 'helpers/utils';
import * as api from '../api';
import SearchResults from './SearchResults';

/*
  api mocks
*/
jest.mock('../api');
api.fetchFuzzyResults.mockImplementation(() => (
  new Promise(resolve => resolve(bikeResponse))
));

/*
  helpers
*/
const noResults = [
  { serial: 'one', bikes: [], fuzzyBikes: [] },
];
const serialResults = [
  {
    ...bikeResponse, fuzzyBikes: [], serial: 'two', anchor: '#mock',
  },
];

describe('<SearchResults />', () => {
  it('matches the snapshot', () => {
    const tree = shallow(<SearchResults />);
    expect(toJson(tree)).toMatchSnapshot();
  });

  it('has a loading indicator when loading', () => {
    const wrap = mount(<SearchResults loading />);
    expect(wrap.exists('Loading')).toBe(true);
  });

  it('is not loading after fetching results', () => {
    const wrap = mount(<SearchResults loading={false} serialResults={noResults} />);
    expect(wrap.exists('Loading')).toBe(false);
  });

  describe('serialResults', () => {
    it('has a no-match class as default', () => {
      const wrap = mount(
        <SearchResults loading={false} serialResults={noResults} />,
      );
      expect(wrap.exists('li.ms-nomatch')).toBe(true);
    });

    it('has a match class if there is a match', () => {
      const wrap = mount(
        <SearchResults loading={false} serialResults={serialResults} />,
      );
      expect(wrap.exists('li.ms-nomatch')).toBe(false);
      expect(wrap.exists('li.ms-match')).toBe(true);
    });

    it('has a div id with the normalized anchor', () => {
      const wrap = mount(
        <SearchResults loading={false} serialResults={serialResults} />,
      );
      const anchorId = serialResults[0].anchor.slice(1);
      expect(wrap.find('.multiserial-results').prop('id')).toEqual(anchorId);
    });

    it('has a BikeList for the matching serial', () => {
      const wrap = mount(
        <SearchResults loading={false} serialResults={serialResults} />,
      );
      const result = serialResults[0];
      expect(wrap.find('BikeList').prop('serial')).toEqual(result.serial);
    });
  });

  it('calls onFuzzySearch on button click', () => {
    const mockFuzzy = jest.fn(() => 'mock api request');
    const wrap = mount(
      <SearchResults loading={false} onFuzzySearch={mockFuzzy} serialResults={serialResults} />,
    );
    wrap.find('button').simulate('click', event);
    expect(mockFuzzy).toHaveBeenCalledTimes(1);
  });
});
