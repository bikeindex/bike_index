import React from "react";
import ClipLoader from "react-spinners/ClipLoader";
import { css } from "@emotion/core";

const overrides = css`
  margin: 0 auto;
  display: block !important;
`;

const Loading = () => (
  <ClipLoader
    css={overrides}
    sizeUnit="px"
    size={100}
    loading
    color="#7a7a7a"
  />
);

export default Loading;
