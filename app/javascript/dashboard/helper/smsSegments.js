// Custom (MyDesk): how many SMS parts a message takes, using the same rule as the Deewan gateway on the server:
// plain ASCII is sent as "text" (160 chars, 153 per part when split), anything else, such as Arabic, as "unicode"
// (70 chars, 67 per part when split).
export const SMS_ENCODINGS = { TEXT: 'text', UNICODE: 'unicode' };

const SEGMENT_LIMITS = {
  [SMS_ENCODINGS.TEXT]: { single: 160, multi: 153 },
  [SMS_ENCODINGS.UNICODE]: { single: 70, multi: 67 },
};
const ASCII_CHAR_LIMIT = 128;

export const smsEncoding = (text = '') =>
  [...text].every(char => char.charCodeAt(0) < ASCII_CHAR_LIMIT)
    ? SMS_ENCODINGS.TEXT
    : SMS_ENCODINGS.UNICODE;

export const smsSegmentCount = (text = '') => {
  const { length } = text;
  if (!length) return 0;
  const limits = SEGMENT_LIMITS[smsEncoding(text)];
  return length <= limits.single ? 1 : Math.ceil(length / limits.multi);
};
