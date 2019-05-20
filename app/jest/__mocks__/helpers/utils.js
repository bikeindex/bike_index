const event = fns => Object.assign(
  jest.fn(),
  {
    ...fns,
    preventDefault: () => {},
  },
);

export {
  event,
};
