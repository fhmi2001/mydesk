// Custom (MyDesk): hands a downloaded report file (a Blob) to the browser to save
export const saveFile = (blob, fileName) => {
  const url = URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.setAttribute('download', fileName);
  link.setAttribute('href', url);
  link.click();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
};
