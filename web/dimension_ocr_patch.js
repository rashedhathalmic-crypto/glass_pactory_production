// Improves image-dimension OCR without touching the NC/CAM generator.
// This module wraps the existing drawingImageAnalyze2d function and merges
// additional readings found with multi-pass preprocessing and orientation scans.

const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));

async function waitForAnalyzer() {
  for (let i = 0; i < 200; i++) {
    if (typeof window.drawingImageAnalyze2d === 'function') return;
    await sleep(25);
  }
  throw new Error('تعذر تهيئة محلل الرسومات.');
}

function normalizeDigits(value) {
  const arabic = '٠١٢٣٤٥٦٧٨٩';
  const eastern = '۰۱۲۳۴۵۶۷۸۹';
  return String(value || '')
    .replace(/[٠-٩]/g, digit => String(arabic.indexOf(digit)))
    .replace(/[۰-۹]/g, digit => String(eastern.indexOf(digit)))
    .replace(/[٫،,]/g, '.')
    .replace(/[−–—]/g, '-')
    .replace(/\s+/g, '')
    .replace(/(?:mm|MM|مم)$/u, '');
}

function numericValue(raw) {
  const normalized = normalizeDigits(raw);
  const match = normalized.match(/-?\d+(?:\.\d+)?/);
  return match ? match[0] : null;
}

function ensureTesseract() {
  if (window.Tesseract) return Promise.resolve(window.Tesseract);
  return new Promise((resolve, reject) => {
    const existing = document.querySelector('script[data-dimension-ocr]');
    if (existing) {
      existing.addEventListener('load', () => resolve(window.Tesseract), {once: true});
      existing.addEventListener('error', () => reject(new Error('تعذر تحميل قارئ الأبعاد.')), {once: true});
      return;
    }
    const script = document.createElement('script');
    script.dataset.dimensionOcr = 'true';
    script.src = 'https://cdn.jsdelivr.net/npm/tesseract.js@5/dist/tesseract.min.js';
    script.async = true;
    script.onload = () => resolve(window.Tesseract);
    script.onerror = () => reject(new Error('تعذر تحميل قارئ الأبعاد.'));
    document.head.appendChild(script);
  });
}

async function imageInfo(blob) {
  const bitmap = await createImageBitmap(blob);
  const info = {width: bitmap.width, height: bitmap.height};
  bitmap.close();
  return info;
}

async function preprocess(blob, mode) {
  const bitmap = await createImageBitmap(blob);
  const maxSide = 2600;
  const scale = Math.max(1, Math.min(4, maxSide / Math.max(bitmap.width, bitmap.height)));
  const canvas = document.createElement('canvas');
  canvas.width = Math.max(1, Math.round(bitmap.width * scale));
  canvas.height = Math.max(1, Math.round(bitmap.height * scale));
  const ctx = canvas.getContext('2d', {willReadFrequently: true});
  ctx.fillStyle = '#fff';
  ctx.fillRect(0, 0, canvas.width, canvas.height);
  ctx.imageSmoothingEnabled = true;
  ctx.imageSmoothingQuality = 'high';
  ctx.drawImage(bitmap, 0, 0, canvas.width, canvas.height);
  bitmap.close();

  if (mode !== 'original') {
    const image = ctx.getImageData(0, 0, canvas.width, canvas.height);
    const data = image.data;
    for (let i = 0; i < data.length; i += 4) {
      const gray = data[i] * 0.299 + data[i + 1] * 0.587 + data[i + 2] * 0.114;
      let value;
      if (mode === 'threshold') value = gray < 190 ? 0 : 255;
      else value = Math.max(0, Math.min(255, (gray - 128) * 1.9 + 128));
      data[i] = data[i + 1] = data[i + 2] = value;
      data[i + 3] = 255;
    }
    ctx.putImageData(image, 0, 0);
  }

  const output = await new Promise((resolve, reject) => {
    canvas.toBlob(value => value ? resolve(value) : reject(new Error('تعذر تجهيز الصورة.')), 'image/png');
  });
  return {blob: output, width: canvas.width, height: canvas.height, scale};
}

async function rotateClockwise(blob) {
  const bitmap = await createImageBitmap(blob);
  const canvas = document.createElement('canvas');
  canvas.width = bitmap.height;
  canvas.height = bitmap.width;
  const ctx = canvas.getContext('2d');
  ctx.fillStyle = '#fff';
  ctx.fillRect(0, 0, canvas.width, canvas.height);
  ctx.translate(canvas.width, 0);
  ctx.rotate(Math.PI / 2);
  ctx.drawImage(bitmap, 0, 0);
  bitmap.close();
  return new Promise((resolve, reject) => {
    canvas.toBlob(value => value ? resolve(value) : reject(new Error('تعذر تدوير الصورة.')), 'image/png');
  });
}

function parseTsv(tsv, orientation, sourceWidth, sourceHeight, processedWidth, processedHeight) {
  if (!tsv) return [];
  const readings = [];
  const rows = tsv.split(/\r?\n/);
  for (let i = 1; i < rows.length; i++) {
    const columns = rows[i].split('\t');
    if (columns.length < 12) continue;
    const confidence = Number(columns[10]);
    if (!Number.isFinite(confidence) || confidence < 30) continue;
    const value = numericValue(columns.slice(11).join('\t'));
    if (value == null) continue;
    const left = Number(columns[6]);
    const top = Number(columns[7]);
    const width = Number(columns[8]);
    const height = Number(columns[9]);
    if (![left, top, width, height].every(Number.isFinite) || width <= 0 || height <= 0) continue;

    let x;
    let y;
    let vertical = false;
    if (orientation === 'rotated') {
      const cx = left + width / 2;
      const cy = top + height / 2;
      x = cy / processedHeight;
      y = 1 - cx / processedWidth;
      vertical = true;
    } else {
      x = (left + width / 2) / processedWidth;
      y = (top + height / 2) / processedHeight;
    }
    if (x < -0.02 || x > 1.02 || y < -0.02 || y > 1.02) continue;
    readings.push({
      value,
      confidence,
      x: Math.max(0, Math.min(1, x)),
      y: Math.max(0, Math.min(1, y)),
      vertical,
      boxWidth: orientation === 'rotated' ? height / processedHeight : width / processedWidth,
      boxHeight: orientation === 'rotated' ? width / processedWidth : height / processedHeight,
      sourceImageWidth: sourceWidth,
      sourceImageHeight: sourceHeight,
    });
  }
  return readings;
}

function mergeReadings(readings) {
  const sorted = readings
    .filter(item => item && numericValue(item.value) != null)
    .map(item => ({...item, value: numericValue(item.value)}))
    .sort((a, b) => b.confidence - a.confidence);
  const merged = [];
  for (const reading of sorted) {
    const duplicate = merged.find(item => {
      const distance = Math.hypot(item.x - reading.x, item.y - reading.y);
      const sameValue = item.value === reading.value;
      return distance < (sameValue ? 0.045 : 0.018);
    });
    if (!duplicate) merged.push(reading);
  }
  return merged
    .sort((a, b) => a.y === b.y ? a.x - b.x : a.y - b.y)
    .map((reading, index) => ({
      id: `dim-${index}-${Math.round(reading.x * 10000)}-${Math.round(reading.y * 10000)}`,
      value: reading.value,
      confidence: reading.confidence,
      x: reading.x,
      y: reading.y,
      vertical: reading.vertical,
      boxWidth: reading.boxWidth || 0,
      boxHeight: reading.boxHeight || 0,
    }));
}

async function enhancedReadings(blob) {
  const Tesseract = await ensureTesseract();
  const source = await imageInfo(blob);
  const worker = await Tesseract.createWorker('eng', 1, {
    workerPath: 'https://cdn.jsdelivr.net/npm/tesseract.js@5/dist/worker.min.js',
    langPath: 'https://tessdata.projectnaptha.com/4.0.0',
    corePath: 'https://cdn.jsdelivr.net/npm/tesseract.js-core@5',
  });
  try {
    await worker.setParameters({
      tessedit_char_whitelist: '0123456789٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹.,٫،-−mmMM',
      preserve_interword_spaces: '1',
      tessedit_pageseg_mode: '11',
    });
    const all = [];
    for (const mode of ['original', 'contrast', 'threshold']) {
      const prepared = await preprocess(blob, mode);
      const normal = await worker.recognize(prepared.blob, {}, {tsv: true});
      all.push(...parseTsv(
        normal.data.tsv,
        'normal',
        source.width,
        source.height,
        prepared.width,
        prepared.height,
      ));
      const rotatedBlob = await rotateClockwise(prepared.blob);
      const rotated = await worker.recognize(rotatedBlob, {}, {tsv: true});
      all.push(...parseTsv(
        rotated.data.tsv,
        'rotated',
        source.width,
        source.height,
        prepared.height,
        prepared.width,
      ));
    }
    return mergeReadings(all);
  } finally {
    await worker.terminate();
  }
}

await waitForAnalyzer();
const originalAnalyze = window.drawingImageAnalyze2d;
window.drawingImageAnalyze2d = async function(bytes, contentType) {
  const baseJson = await originalAnalyze(bytes, contentType);
  const analysis = JSON.parse(baseJson);
  const data = bytes instanceof Uint8Array ? bytes : new Uint8Array(bytes);
  const blob = new Blob([data], {type: contentType || 'image/png'});
  try {
    const added = await enhancedReadings(blob);
    analysis.dimensionReadings = mergeReadings([
      ...(analysis.dimensionReadings || []),
      ...added,
    ]);
  } catch (error) {
    console.warn('Enhanced dimension OCR failed; keeping base OCR results.', error);
  }
  return JSON.stringify(analysis);
};

window.drawingImageAnalyze2dCallback = function(bytes, contentType, onSuccess, onError) {
  window.drawingImageAnalyze2d(bytes, contentType)
    .then(result => onSuccess(result))
    .catch(error => onError(error && error.message ? error.message : String(error)));
};
