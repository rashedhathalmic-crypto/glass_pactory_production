import * as pdfjsLib from 'https://cdnjs.cloudflare.com/ajax/libs/pdf.js/4.10.38/pdf.min.mjs';

pdfjsLib.GlobalWorkerOptions.workerSrc =
  'https://cdnjs.cloudflare.com/ajax/libs/pdf.js/4.10.38/pdf.worker.min.mjs';

window.pdfRenderFirstPagePngBase64 = async function(bytes) {
  const data = bytes instanceof Uint8Array ? bytes : new Uint8Array(bytes);
  const documentTask = pdfjsLib.getDocument({data});
  const pdf = await documentTask.promise;
  const page = await pdf.getPage(1);
  const baseViewport = page.getViewport({scale: 1});
  const longest = Math.max(baseViewport.width, baseViewport.height);
  const scale = Math.max(0.65, Math.min(3, 2400 / Math.max(1, longest)));
  const viewport = page.getViewport({scale});
  const canvas = document.createElement('canvas');
  canvas.width = Math.max(1, Math.ceil(viewport.width));
  canvas.height = Math.max(1, Math.ceil(viewport.height));
  const context = canvas.getContext('2d', {willReadFrequently: true});
  context.fillStyle = '#ffffff';
  context.fillRect(0, 0, canvas.width, canvas.height);
  await page.render({
    canvasContext: context,
    viewport,
    background: '#ffffff',
  }).promise;
  const dataUrl = canvas.toDataURL('image/png');
  const separator = dataUrl.indexOf(',');
  if (separator < 0) throw new Error('تعذر تجهيز صفحة PDF.');
  return dataUrl.slice(separator + 1);
};
