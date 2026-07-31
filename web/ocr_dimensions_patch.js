const previousDrawingImageAnalyze2d = window.drawingImageAnalyze2d;

let dimensionPatchTesseractLoader;

function loadDimensionPatchTesseract() {
  if (window.Tesseract) return Promise.resolve(window.Tesseract);
  if (dimensionPatchTesseractLoader) return dimensionPatchTesseractLoader;
  dimensionPatchTesseractLoader = new Promise((resolve, reject) => {
    const script = document.createElement('script');
    script.src =
      'https://cdn.jsdelivr.net/npm/tesseract.js@5/dist/tesseract.min.js';
    script.async = true;
    script.onload = () => resolve(window.Tesseract);
    script.onerror = () => reject(new Error('تعذر تحميل قارئ الأرقام الاحتياطي.'));
    document.head.appendChild(script);
  });
  return dimensionPatchTesseractLoader;
}

function canvasToPngBlob(canvas) {
  return new Promise((resolve, reject) => {
    canvas.toBlob(
      value => value
        ? resolve(value)
        : reject(new Error('تعذر تجهيز الصورة لقراءة الأبعاد.')),
      'image/png',
    );
  });
}

async function prepareHorizontalOcrImages(blob) {
  const bitmap = await createImageBitmap(blob);
  const factor = Math.max(
    1,
    Math.min(4, 3200 / Math.max(bitmap.width, bitmap.height)),
  );
  const width = Math.max(1, Math.round(bitmap.width * factor));
  const height = Math.max(1, Math.round(bitmap.height * factor));

  const normalCanvas = document.createElement('canvas');
  normalCanvas.width = width;
  normalCanvas.height = height;
  const normalContext = normalCanvas.getContext('2d', {
    willReadFrequently: true,
  });
  normalContext.fillStyle = '#ffffff';
  normalContext.fillRect(0, 0, width, height);
  normalContext.imageSmoothingEnabled = true;
  normalContext.imageSmoothingQuality = 'high';
  normalContext.drawImage(bitmap, 0, 0, width, height);
  bitmap.close();

  const thresholdCanvas = document.createElement('canvas');
  thresholdCanvas.width = width;
  thresholdCanvas.height = height;
  const thresholdContext = thresholdCanvas.getContext('2d');
  const image = normalContext.getImageData(0, 0, width, height);
  for (let offset = 0; offset < image.data.length; offset += 4) {
    const luminance =
      image.data[offset] * 0.299 +
      image.data[offset + 1] * 0.587 +
      image.data[offset + 2] * 0.114;
    const value = luminance < 215 ? 0 : 255;
    image.data[offset] = value;
    image.data[offset + 1] = value;
    image.data[offset + 2] = value;
    image.data[offset + 3] = 255;
  }
  thresholdContext.putImageData(image, 0, 0);

  return {
    width,
    height,
    normal: await canvasToPngBlob(normalCanvas),
    threshold: await canvasToPngBlob(thresholdCanvas),
  };
}

function cleanNumericOcrText(value) {
  return String(value || '')
    .trim()
    .replaceAll(',', '.')
    .replace(/[Oo]/g, '0')
    .replace(/[Il|]/g, '1')
    .replace(/[^0-9.\-]/g, '');
}

function horizontalNumbersFromTsv(tsv, imageWidth, imageHeight) {
  if (!tsv) return [];
  const words = [];
  const rows = tsv.split(/\r?\n/);
  for (let index = 1; index < rows.length; index++) {
    const columns = rows[index].split('\t');
    if (columns.length < 12) continue;
    const confidence = Number(columns[10]);
    if (!Number.isFinite(confidence) || confidence < 12) continue;
    const text = cleanNumericOcrText(columns.slice(11).join('\t'));
    if (!text || !/\d/.test(text)) continue;
    const left = Number(columns[6]);
    const top = Number(columns[7]);
    const width = Number(columns[8]);
    const height = Number(columns[9]);
    if (![left, top, width, height].every(Number.isFinite)) continue;
    if (width <= 1 || height <= 1) continue;
    words.push({
      key: `${columns[2]}:${columns[3]}:${columns[4]}`,
      text,
      confidence,
      left,
      top,
      width,
      height,
    });
  }

  const byLine = new Map();
  for (const word of words) {
    if (!byLine.has(word.key)) byLine.set(word.key, []);
    byLine.get(word.key).push(word);
  }

  const readings = [];
  const addGroup = group => {
    if (!group.length) return;
    const text = group.map(item => item.text).join('');
    if (!/^-?\d+(?:\.\d+)?$/.test(text)) return;
    const numeric = Number(text);
    if (!Number.isFinite(numeric) || numeric <= 0 || numeric > 1000000) {
      return;
    }
    const left = Math.min(...group.map(item => item.left));
    const top = Math.min(...group.map(item => item.top));
    const right = Math.max(...group.map(item => item.left + item.width));
    const bottom = Math.max(...group.map(item => item.top + item.height));
    const confidence = group.reduce(
      (sum, item) => sum + item.confidence,
      0,
    ) / group.length;
    readings.push({
      value: text,
      confidence,
      x: ((left + right) / 2) / imageWidth,
      y: ((top + bottom) / 2) / imageHeight,
      vertical: false,
    });
  };

  for (const lineWords of byLine.values()) {
    lineWords.sort((a, b) => a.left - b.left);
    let group = [];
    const flush = () => {
      const captured = group;
      group = [];
      addGroup(captured);
    };

    for (const word of lineWords) {
      if (!group.length) {
        group.push(word);
        continue;
      }
      const previous = group[group.length - 1];
      const gap = word.left - (previous.left + previous.width);
      const allowedGap = Math.max(previous.height, word.height) * 0.85;
      if (gap <= allowedGap) {
        group.push(word);
      } else {
        flush();
        group.push(word);
      }
    }
    flush();
  }
  return readings;
}

function mergeDimensionReadings(readings) {
  const merged = [];
  for (const reading of readings) {
    if (!Number.isFinite(reading.x) || !Number.isFinite(reading.y)) continue;
    if (reading.x < 0 || reading.x > 1 || reading.y < 0 || reading.y > 1) {
      continue;
    }
    const nearby = merged.find(item =>
      item.vertical === reading.vertical &&
      Math.hypot(item.x - reading.x, item.y - reading.y) < 0.04);
    if (!nearby) {
      merged.push({...reading});
      continue;
    }
    const oldScore = nearby.confidence + String(nearby.value).length * 2;
    const newScore = reading.confidence + String(reading.value).length * 2;
    if (newScore > oldScore) Object.assign(nearby, reading);
  }
  return merged.sort((a, b) =>
    a.vertical === b.vertical
      ? a.y === b.y ? a.x - b.x : a.y - b.y
      : Number(a.vertical) - Number(b.vertical));
}

async function retryHorizontalDimensions(blob) {
  const Tesseract = await loadDimensionPatchTesseract();
  const prepared = await prepareHorizontalOcrImages(blob);
  const worker = await Tesseract.createWorker('eng', 1, {
    workerPath:
      'https://cdn.jsdelivr.net/npm/tesseract.js@5/dist/worker.min.js',
    langPath: 'https://tessdata.projectnaptha.com/4.0.0',
    corePath: 'https://cdn.jsdelivr.net/npm/tesseract.js-core@5',
  });
  try {
    await worker.setParameters({
      tessedit_char_whitelist: '0123456789.-',
      tessedit_pageseg_mode: '11',
      preserve_interword_spaces: '1',
    });
    const sparse = await worker.recognize(
      prepared.normal,
      {},
      {tsv: true},
    );
    await worker.setParameters({
      tessedit_char_whitelist: '0123456789.-',
      tessedit_pageseg_mode: '6',
      preserve_interword_spaces: '1',
    });
    const block = await worker.recognize(
      prepared.threshold,
      {},
      {tsv: true},
    );
    return mergeDimensionReadings([
      ...horizontalNumbersFromTsv(
        sparse.data.tsv,
        prepared.width,
        prepared.height,
      ),
      ...horizontalNumbersFromTsv(
        block.data.tsv,
        prepared.width,
        prepared.height,
      ),
    ]);
  } finally {
    await worker.terminate();
  }
}

if (typeof previousDrawingImageAnalyze2d === 'function') {
  window.drawingImageAnalyze2d = async function(bytes, contentType) {
    const result = await previousDrawingImageAnalyze2d(bytes, contentType);
    const analysis = JSON.parse(result);
    const current = Array.isArray(analysis.dimensionReadings)
      ? analysis.dimensionReadings
      : [];

    try {
      const data = bytes instanceof Uint8Array
        ? bytes
        : new Uint8Array(bytes);
      const blob = new Blob([data], {
        type: contentType || 'image/png',
      });
      const recovered = await retryHorizontalDimensions(blob);
      analysis.dimensionReadings = mergeDimensionReadings([
        ...current,
        ...recovered,
      ]);
    } catch (error) {
      console.warn('Horizontal dimension recovery failed:', error);
      analysis.dimensionReadings = current;
    }
    return JSON.stringify(analysis);
  };
}
