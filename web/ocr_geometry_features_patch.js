const previousGeometryAnalyze2d = window.drawingImageAnalyze2d;

let geometryFeatureTesseractLoader;

function loadGeometryFeatureTesseract() {
  if (window.Tesseract) return Promise.resolve(window.Tesseract);
  if (geometryFeatureTesseractLoader) return geometryFeatureTesseractLoader;
  geometryFeatureTesseractLoader = new Promise((resolve, reject) => {
    const script = document.createElement('script');
    script.src =
      'https://cdn.jsdelivr.net/npm/tesseract.js@5/dist/tesseract.min.js';
    script.async = true;
    script.onload = () => resolve(window.Tesseract);
    script.onerror = () => reject(new Error('تعذر تحميل قارئ الزوايا والشنفر.'));
    document.head.appendChild(script);
  });
  return geometryFeatureTesseractLoader;
}

function cleanGeometryText(value) {
  return String(value || '')
    .trim()
    .replaceAll(',', '.')
    .replace(/[Oo]/g, '0')
    .replace(/[Il|]/g, '1')
    .replace(/[×]/g, 'X')
    .toUpperCase();
}

function geometryWordsFromTsv(tsv) {
  if (!tsv) return [];
  const words = [];
  const rows = tsv.split(/\r?\n/);
  for (let index = 1; index < rows.length; index++) {
    const columns = rows[index].split('\t');
    if (columns.length < 12) continue;
    const confidence = Number(columns[10]);
    if (!Number.isFinite(confidence) || confidence < 10) continue;
    const text = String(columns.slice(11).join('\t') || '').trim();
    if (!text) continue;
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
  return words;
}

function geometryLineGroups(words) {
  const lines = new Map();
  for (const word of words) {
    if (!lines.has(word.key)) lines.set(word.key, []);
    lines.get(word.key).push(word);
  }
  for (const line of lines.values()) line.sort((a, b) => a.left - b.left);
  return [...lines.values()];
}

function geometryReading(group, imageWidth, imageHeight, value, kind) {
  const left = Math.min(...group.map(item => item.left));
  const top = Math.min(...group.map(item => item.top));
  const right = Math.max(...group.map(item => item.left + item.width));
  const bottom = Math.max(...group.map(item => item.top + item.height));
  return {
    value: String(value),
    confidence: group.reduce((sum, item) => sum + item.confidence, 0) /
      group.length,
    x: ((left + right) / 2) / imageWidth,
    y: ((top + bottom) / 2) / imageHeight,
    vertical: false,
    kind,
  };
}

function geometryFeaturesFromTsv(tsv, imageWidth, imageHeight) {
  const readings = [];
  for (const group of geometryLineGroups(geometryWordsFromTsv(tsv))) {
    const compact = cleanGeometryText(group.map(item => item.text).join(' '))
      .replace(/\s+/g, '');
    if (!/\d/.test(compact)) continue;

    let chamferValue;
    let chamferNotation = false;
    let match = compact.match(/CHAMFER[:=]?([0-9]+(?:\.[0-9]+)?)/);
    if (match) {
      chamferValue = Number(match[1]);
      chamferNotation = true;
    }
    if (chamferValue == null) {
      match = compact.match(
        /^C([0-9]+(?:\.[0-9]+)?)(?:X[0-9]+(?:\.[0-9]+)?(?:°|DEG)?)?$/,
      );
      if (match) {
        chamferValue = Number(match[1]);
        chamferNotation = true;
      }
    }
    if (chamferValue == null) {
      match = compact.match(/([0-9]+(?:\.[0-9]+)?)X45(?:°|DEG)?/);
      if (match) {
        chamferValue = Number(match[1]);
        chamferNotation = true;
      }
    }
    if (Number.isFinite(chamferValue) && chamferValue > 0) {
      readings.push(
        geometryReading(
          group,
          imageWidth,
          imageHeight,
          chamferValue,
          'chamfer',
        ),
      );
    }

    if (chamferNotation) continue;
    match = compact.match(/([0-9]+(?:\.[0-9]+)?)(?:°|DEG)/);
    if (!match) continue;
    const angle = Number(match[1]);
    if (!Number.isFinite(angle) || angle <= 0 || angle >= 180) continue;
    readings.push(
      geometryReading(group, imageWidth, imageHeight, angle, 'angle'),
    );
  }
  return readings;
}

function readingKind(reading) {
  const kind = String(reading.kind || reading.type || 'linear').toLowerCase();
  if (kind === 'angle' || kind === 'degree' || kind === 'degrees') {
    return 'angle';
  }
  if (kind === 'chamfer' || kind === 'c') return 'chamfer';
  return 'linear';
}

function mergeGeometryFeatures(current, features) {
  const merged = current.map(reading => ({
    ...reading,
    kind: readingKind(reading),
  }));
  for (const feature of features) {
    for (let index = merged.length - 1; index >= 0; index--) {
      const existing = merged[index];
      const distance = Math.hypot(
        Number(existing.x) - feature.x,
        Number(existing.y) - feature.y,
      );
      if (distance >= 0.055) continue;
      if (existing.kind === 'linear') {
        merged.splice(index, 1);
      } else if (existing.kind === feature.kind) {
        if (Number(feature.confidence) > Number(existing.confidence || 0)) {
          merged[index] = feature;
        }
        return merged;
      }
    }
    merged.push(feature);
  }
  return merged;
}

async function readGeometryFeatures(blob) {
  const bitmap = await createImageBitmap(blob);
  const imageWidth = bitmap.width;
  const imageHeight = bitmap.height;
  bitmap.close();

  const Tesseract = await loadGeometryFeatureTesseract();
  const worker = await Tesseract.createWorker('eng', 1, {
    workerPath:
      'https://cdn.jsdelivr.net/npm/tesseract.js@5/dist/worker.min.js',
    langPath: 'https://tessdata.projectnaptha.com/4.0.0',
    corePath: 'https://cdn.jsdelivr.net/npm/tesseract.js-core@5',
  });
  try {
    await worker.setParameters({
      tessedit_char_whitelist:
        '0123456789.,-°xXCcHhAaMmFfEeRrDdGg',
      tessedit_pageseg_mode: '11',
      preserve_interword_spaces: '1',
    });
    const result = await worker.recognize(blob, {}, {tsv: true});
    return geometryFeaturesFromTsv(
      result.data.tsv,
      imageWidth,
      imageHeight,
    );
  } finally {
    await worker.terminate();
  }
}

if (typeof previousGeometryAnalyze2d === 'function') {
  window.drawingImageAnalyze2d = async function(bytes, contentType) {
    const result = await previousGeometryAnalyze2d(bytes, contentType);
    const analysis = JSON.parse(result);
    const current = Array.isArray(analysis.dimensionReadings)
      ? analysis.dimensionReadings
      : [];
    try {
      const data = bytes instanceof Uint8Array
        ? bytes
        : new Uint8Array(bytes);
      const blob = new Blob([data], {type: contentType || 'image/png'});
      const features = await readGeometryFeatures(blob);
      analysis.dimensionReadings = mergeGeometryFeatures(current, features);
    } catch (error) {
      console.warn('Angle/chamfer OCR failed:', error);
      analysis.dimensionReadings = current.map(reading => ({
        ...reading,
        kind: readingKind(reading),
      }));
    }
    return JSON.stringify(analysis);
  };
}
