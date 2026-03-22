import { formatKRW, formatUSD, formatPercent, formatShares, formatRelativeTime } from '../../src/utils/format';

describe('formatKRW', () => {
  it('formats positive KRW', () => {
    expect(formatKRW(1301037659)).toBe('₩1,301,037,659');
  });
  it('rounds decimals', () => {
    expect(formatKRW(1234.56)).toBe('₩1,235');
  });
  it('formats negative', () => {
    expect(formatKRW(-500000)).toBe('₩-500,000');
  });
});

describe('formatUSD', () => {
  it('formats USD with 2 decimals', () => {
    expect(formatUSD(367.96)).toBe('$367.96');
  });
});

describe('formatPercent', () => {
  it('formats positive with + sign', () => {
    expect(formatPercent(15.71)).toBe('+15.71%');
  });
  it('formats negative', () => {
    expect(formatPercent(-3.24)).toBe('-3.24%');
  });
  it('formats zero', () => {
    expect(formatPercent(0)).toBe('+0.00%');
  });
});

describe('formatShares', () => {
  it('formats with comma separator', () => {
    expect(formatShares(7300)).toBe('7,300');
  });
});

describe('formatRelativeTime', () => {
  it('returns 방금 전 for recent time', () => {
    expect(formatRelativeTime(new Date().toISOString())).toBe('방금 전');
  });
});
