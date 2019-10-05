/* eslint import/no-unresolved: 0 */

import React from "react";
import { shallow, mount } from "enzyme";
import toJson from "enzyme-to-json";

import { event } from "helpers/utils";
import { externalBikeResponse } from "helpers/bikes";

import * as api from "../../api";
import ExternalRegistrySearch from "./ExternalRegistrySearch";

describe("<ExternalRegistrySearch />", () => {
  it("matches the snapshot when loading", () => {
    const tree = shallow(<ExternalRegistrySearch serial="23545"/>);
    expect(toJson(tree)).toMatchSnapshot();
  });

  it("has a loading indicator when loading", () => {
    const wrap = mount(<ExternalRegistrySearch serial="12345"/>);
    expect(wrap.exists("Loading")).toBe(true);
  });

  it("is not loading after fetching results", () => {
    const wrap = mount(<ExternalRegistrySearch serial="12345"/>);
    wrap.setState({ loading: false, bikes: externalBikeResponse });
    expect(wrap.exists("Loading")).toBe(false);
  });
});
