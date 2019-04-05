
import React from 'react';
import { mount, shallow } from 'enzyme';
import toJson from 'enzyme-to-json';
import * as api from '../api';
import MultiSerialSearch from './MultiSerialSearch';


jest.mock('../api');

/*
  event helper
*/
const event = fns => Object.assign(
  jest.fn(),
  {
    ...fns,
    preventDefault: () => {},
  },
);

describe('<MultiSerialSearch /> mount rendered', () => {
  it('matches the snapshot', () => {
    const tree = mount(<MultiSerialSearch />);
    expect(toJson(tree)).toMatchSnapshot();
  });

  it('toggles the form visibility', () => {
    const wrap = mount(<MultiSerialSearch />);
    wrap.find('.multi-search-toggle a').simulate('click');
    expect(wrap.exists('.multiserial-form')).toBe(true);
  });

  it('makes an api request to search serials', () => {
    jest.spyOn(api, 'fetchSerialResults');

    // - toggle form visibility
    const wrap = shallow(<MultiSerialSearch />);
    wrap.find('.multi-search-toggle a').simulate('click', event());

    // - enter and submit multiple serials
    const input = wrap.find('textarea');
    input.simulate('change', event({ target: { value: 'one,two,three' } }));
    wrap.find('.multiserial-form button').simulate('click');

    // one call per serial delimited by comma
    expect(api.fetchSerialResults).toHaveBeenCalledTimes(3);
  });
});
