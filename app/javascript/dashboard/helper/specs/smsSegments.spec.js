import { smsEncoding, smsSegmentCount, SMS_ENCODINGS } from '../smsSegments';

describe('smsSegments', () => {
  it('detects plain text and unicode messages', () => {
    expect(smsEncoding('your otp is 01234')).toBe(SMS_ENCODINGS.TEXT);
    expect(smsEncoding('رمز التحقق 01234')).toBe(SMS_ENCODINGS.UNICODE);
  });

  it('counts parts for plain text', () => {
    expect(smsSegmentCount('')).toBe(0);
    expect(smsSegmentCount('a'.repeat(160))).toBe(1);
    expect(smsSegmentCount('a'.repeat(161))).toBe(2);
    expect(smsSegmentCount('a'.repeat(306))).toBe(2);
    expect(smsSegmentCount('a'.repeat(307))).toBe(3);
  });

  it('counts parts for Arabic text', () => {
    expect(smsSegmentCount('م'.repeat(70))).toBe(1);
    expect(smsSegmentCount('م'.repeat(71))).toBe(2);
    expect(smsSegmentCount('م'.repeat(135))).toBe(3);
  });
});
