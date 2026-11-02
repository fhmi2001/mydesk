// Custom (MyDesk): prints a report as A4 pages; the browser's "Save as PDF" makes the PDF. The report as drawn on screen
// is copied into a hidden frame with the app's own styles, under a header that says what was printed (the report, its
// question, the period, every filter, who printed it and when), with the page number on each page.
export const escapeHtml = value =>
  String(value ?? '').replace(
    /[&<>"']/g,
    c =>
      ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[
        c
      ]
  );

// A CSS string literal (for the page footer)
const cssString = value =>
  `"${String(value ?? '')
    .replace(/[\\"]/g, '\\$&')
    .replace(/\n/g, ' ')}"`;

const printCss = footer => `
  @page {
    size: A4;
    margin: 14mm 12mm 16mm;
    @bottom-center { content: counter(page) " / " counter(pages); font-size: 8pt; color: #60646C; }
    @bottom-right { content: ${cssString(footer)}; font-size: 8pt; color: #60646C; }
  }
  html, body { background: #fff !important; height: auto !important; overflow: visible !important; }
  body { margin: 0; color: #1C2024; font-size: 10pt; -webkit-print-color-adjust: exact; print-color-adjust: exact; }
  .overflow-x-auto, .overflow-y-auto, .overflow-hidden { overflow: visible !important; }
  section, tr, li, .rp-avoid { break-inside: avoid; }
  thead { display: table-header-group; }
  table { width: 100%; border-collapse: collapse; }
  button { color: inherit !important; text-decoration: none !important; cursor: default; }
  a { color: inherit !important; text-decoration: none !important; }
  svg:not([class*="size-"]) { max-width: 100%; }
  [data-print-hide] { display: none !important; }
  .grid:has(table) { grid-template-columns: minmax(0, 1fr) !important; }
  .rp-head { border-top: 6px solid #7C3AED; padding: 14px 0 12px; margin-bottom: 16px; border-bottom: 1px solid #E2E3E7; }
  .rp-brand { display: flex; justify-content: space-between; align-items: center; font-size: 9pt; color: #60646C; }
  .rp-logo { font-weight: 700; letter-spacing: .02em; color: #7C3AED; font-size: 11pt; }
  .rp-number { display: inline-block; background: #EDE9FE; color: #5B21B6; border-radius: 999px; padding: 1px 9px; font-size: 8.5pt; }
  .rp-title { margin: 10px 0 2px; font-size: 18pt; font-weight: 500; color: #1C2024; }
  .rp-question { margin: 0 0 12px; font-size: 11pt; color: #60646C; }
  .rp-meta { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 6px 18px; margin: 0;
    padding: 10px 12px; background: #F7F7F7; border: 1px solid #EAEAEA; border-radius: 8px; }
  .rp-meta div { min-width: 0; }
  .rp-meta dt { font-size: 7.5pt; color: #60646C; margin: 0; }
  .rp-meta dd { font-size: 9.5pt; color: #1C2024; margin: 1px 0 0; font-weight: 500; }
  .rp-note { margin: 10px 0 0; font-size: 8.5pt; color: #60646C; }
`;

const waitForStyles = doc =>
  Promise.all(
    [...doc.querySelectorAll('link[rel="stylesheet"]')].map(
      link =>
        new Promise(resolve => {
          if (link.sheet) resolve();
          link.addEventListener('load', resolve, { once: true });
          link.addEventListener('error', resolve, { once: true });
          setTimeout(resolve, 4000);
        })
    )
  );

// { title, dir, lang, header (HTML), body (HTML), footer (text) }
export const printReport = async ({
  title,
  dir,
  lang,
  header,
  body,
  footer,
}) => {
  const frame = document.createElement('iframe');
  frame.setAttribute('aria-hidden', 'true');
  frame.tabIndex = -1;
  Object.assign(frame.style, {
    position: 'fixed',
    insetInlineEnd: '0',
    bottom: '0',
    width: '210mm',
    height: '0',
    border: '0',
    visibility: 'hidden',
  });
  document.body.appendChild(frame);

  const styles = [...document.querySelectorAll('link[rel="stylesheet"], style')]
    .map(node => node.outerHTML)
    .join('\n');
  const doc = frame.contentDocument;
  doc.open();
  doc.write(`<!doctype html><html lang="${escapeHtml(lang)}" dir="${escapeHtml(dir)}"><head><meta charset="utf-8">
    <title>${escapeHtml(title)}</title>${styles}<style>${printCss(footer)}</style></head>
    <body>${header}<main>${body}</main></body></html>`);
  doc.close();

  await waitForStyles(doc);
  await doc.fonts?.ready;
  frame.contentWindow.focus();
  frame.contentWindow.print();
  // print() blocks until the dialog closes in most browsers; the delay covers those where it does not
  setTimeout(() => frame.remove(), 1000);
};
