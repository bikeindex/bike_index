/* eslint import/no-unresolved: 0 */

import React from "react";
import { shallow } from "enzyme";
import toJson from "enzyme-to-json";
import { bikeResponse } from "helpers/bikes";
import { event } from "helpers/utils";
import api from "../../api";
import MultiSerialSearch from "./MultiSerialSearch";

/*
  api mocks
*/
jest.mock("../../api");
api.fetchSerialResults.mockImplementation(
  () => new Promise(resolve => resolve(bikeResponse))
);

describe("<MultiSerialSearch /> shallow rendered", () => {
  it("matches the snapshot", () => {
    const tree = shallow(<MultiSerialSearch />);
    expect(toJson(tree)).toMatchSnapshot();
  });

  it("searches multiple serials", () => {
    jest.spyOn(api, "fetchSerialResults");

    // - toggle form visibility
    const wrap = shallow(<MultiSerialSearch />);

    // - enter and submit multiple serials
    const input = wrap.find("textarea");
    input.simulate("change", event({ target: { value: "one,two,three" } }));
    wrap.find(".multiserial-form button").simulate("click");

    // one call per serial delimited by comma
    expect(api.fetchSerialResults).toHaveBeenCalledTimes(3);
  });
});
