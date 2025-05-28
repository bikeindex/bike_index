// 2023-8-25 - Updated withPreposition

import TimeLocalizer from "utils/time_localizer";

window.localTimezone = "America/Los_Angeles"; // For consistency in testing
const timeLocalizer = new TimeLocalizer();

test("time_parser returns invalid date for unparseable time", () => {
  const target = '<span title="Invalid date">Invalid date</span>';

  expect(timeLocalizer.localizedTimeHtml("   ", {})).toBe(target);
  expect(timeLocalizer.localizedTimeHtml("ADF*(asdcx89z89xcv", {})).toBe(
    target,
  );
});

test("time_parser formats time from years ago", () => {
  const target = '<span title="2019-06-03 11:55:14 am">2019-06-03</span>';

  expect(timeLocalizer.localizedTimeHtml("2019-06-03T11:55:14-0700", {})).toBe(
    target,
  );
  // Also converts unix timestamps
  expect(timeLocalizer.localizedTimeHtml("1559588114", {})).toBe(target);
  // and should work for integer timestamps
  expect(timeLocalizer.localizedTimeHtml(1559588114, {})).toBe(target);
});

test("time_parser formats time from years ago", () => {
  const dateString = "2019-06-03 11:55:14 am";
  expect(timeLocalizer.localTimezone).toBe("America/Los_Angeles");
  expect(
    timeLocalizer.localizedTimeHtml(1559588114, { withPreposition: true }),
  ).toBe(`<span title="${dateString}">on 2019-06-03</span>`);

  expect(
    timeLocalizer.localizedTimeHtml(1559588114, {
      withPreposition: true,
      preciseTime: true,
    }),
  ).toBe(
    `<span title="${dateString}">on 2019-06-03 <span class="less-strong">at 11:55am</span></span>`,
  );
  expect(
    timeLocalizer.localizedTimeHtml(1559588114, { preciseTime: true }),
  ).toBe(
    `<span title="${dateString}">2019-06-03 <span class="less-strong">11:55am</span></span>`,
  );

  expect(
    timeLocalizer.localizedTimeHtml(1559588114, {
      preciseTime: true,
      includeSeconds: true,
    }),
  ).toBe(
    `<span title="${dateString}">2019-06-03 <span class="less-strong">11:55:<small>14</small> am</span></span>`,
  );

  // with a different timezone - Doesn't work because moment.tz.setDefault. TODO: make it actually work
  // timeLocalizer.localTimezone = "America/Chicago";
  // expect(timeLocalizer.localTimezone).toBe("America/Chicago");
  // console.log(timeLocalizer.localTimezone);
  // expect(timeLocalizer.localizedTimeHtml(1559588114, { preciseTime: true })).toBe(
  //   '<span title="2019-06-03 1:55:14 pm">2019-06-03 <span class="less-strong">1:55pm</span></span>'
  // );
});

test("time_parser from today", () => {
  const timeStamp = timeLocalizer.todayStart.unix() + 42240; // 11:44am
  const tzoffset = -28800000; // PST offset
  const dateString = new Date(Date.now() + tzoffset)
    .toISOString()
    .substring(0, 10);

  expect(timeLocalizer.localizedTimeHtml(timeStamp, {})).toBe(
    `<span title="${dateString} 11:44:00 am">11:44am</span>`,
  );

  // With includeSeconds and withPreposition
  expect(
    timeLocalizer.localizedTimeHtml(timeStamp, {
      includeSeconds: true,
      withPreposition: true,
    }),
  ).toBe(
    `<span title="${dateString} 11:44:00 am">at 11:44:<small>00</small> am</span>`,
  );
  // With preciseTime
  expect(
    timeLocalizer.localizedTimeHtml(timeStamp, { preciseTime: true }),
  ).toBe(`<span title="${dateString} 11:44:00 am">11:44am</span>`);
  // With singleFormat
  expect(
    timeLocalizer.localizedTimeHtml(timeStamp, { singleFormat: true }),
  ).toBe(`<span title="${dateString} 11:44:00 am">${dateString}</span>`);
});

test("time_parser from yesterday", () => {
  const timeStamp = timeLocalizer.todayStart.unix() - 15120; // 7:48pm
  const dateString = timeLocalizer.yesterdayStart.format("YYYY-MM-DD");

  expect(
    timeLocalizer.localizedTimeHtml(timeStamp, { withPreposition: true }),
  ).toBe(`<span title="${dateString} 7:48:00 pm">Yesterday at 7:48pm</span>`);

  expect(timeLocalizer.localizedTimeHtml(timeStamp, {})).toBe(
    `<span title="${dateString} 7:48:00 pm">Yesterday 7:48pm</span>`,
  );

  // With preciseTime
  expect(
    timeLocalizer.localizedTimeHtml(timeStamp, { preciseTime: true }),
  ).toBe(`<span title="${dateString} 7:48:00 pm">Yesterday 7:48pm</span>`);
  // With singleFormat
  expect(
    timeLocalizer.localizedTimeHtml(timeStamp, { singleFormat: true }),
  ).toBe(`<span title="${dateString} 7:48:00 pm">${dateString}</span>`);
});
