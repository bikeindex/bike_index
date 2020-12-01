import loglevel from "loglevel";

if (process.env.RAILS_ENV !== "production") loglevel.setLevel("debug");

export default loglevel;
