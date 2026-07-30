import * as pdfjsLib from 'https://cdnjs.cloudflare.com/ajax/libs/pdf.js/4.10.38/pdf.min.mjs';

pdfjsLib.GlobalWorkerOptions.workerSrc =
  'https://cdnjs.cloudflare.com/ajax/libs/pdf.js/4.10.38/pdf.worker.min.mjs';

const apply = (m, x, y) => [
  m[0] * x + m[2] * y + m[4],
  m[1] * x + m[3] * y + m[5],
];

const multiply = (a, b) => [
  a[0] * b[0] + a[2] * b[1],
  a[1] * b[0] + a[3] * b[1],
  a[0] * b[2] + a[2] * b[3],
  a[1] * b[2] + a[3] * b[3],
  a[0] * b[4] + a[2] * b[5] + a[4],
  a[1] * b[4] + a[3] * b[5] + a[5],
];

const distance = (a, b) => Math.hypot(a[0] - b[0], a[1] - b[1]);
const near = (a, b, tolerance = 0.75) => distance(a, b) <= tolerance;

function cubic(points, p0, p1, p2, p3) {
  for (let i = 1; i <= 16; i++) {
    const t = i / 16;
    const u = 1 - t;
    points.push([
      u*u*u*p0[0] + 3*u*u*t*p1[0] + 3*u*t*t*p2[0] + t*t*t*p3[0],
      u*u*u*p0[1] + 3*u*u*t*p1[1] + 3*u*t*t*p2[1] + t*t*t*p3[1],
    ]);
  }
}

function simplify(points) {
  const clean = [];
  for (const point of points) {
    if (!clean.length || !near(clean[clean.length - 1], point, 0.01)) {
      clean.push(point);
    }
  }
  if (clean.length > 2 && near(clean[0], clean[clean.length - 1], 0.01)) {
    clean.pop();
  }

  let changed = true;
  while (changed && clean.length > 3) {
    changed = false;
    for (let i = 0; i < clean.length; i++) {
      const a = clean[(i - 1 + clean.length) % clean.length];
      const b = clean[i];
      const c = clean[(i + 1) % clean.length];
      const ac = distance(a, c);
      if (ac < 0.01) continue;
      const cross = Math.abs((b[0] - a[0]) * (c[1] - a[1]) -
        (b[1] - a[1]) * (c[0] - a[0])) / ac;
      const between =
        (b[0] - a[0]) * (b[0] - c[0]) +
        (b[1] - a[1]) * (b[1] - c[1]) <= 0.01;
      if (cross <= 0.01 && between) {
        clean.splice(i, 1);
        changed = true;
        break;
      }
    }
  }
  return clean;
}

function buildProfileCandidates(paths, tolerance = 1.5) {
  const candidates = paths
    .filter(path => path.closed && path.points.length >= 3)
    .map(path => ({
      points: simplify(path.points),
      sourceCount: 1,
      impliedClose: false,
    }));

  const pending = paths
    .filter(path => !path.closed && path.points.length >= 2)
    .map(path => path.points.slice());

  while (pending.length) {
    let chain = pending.shift();
    let sourceCount = 1;
    let changed = true;

    while (changed) {
      changed = false;
      for (let i = 0; i < pending.length; i++) {
        const next = pending[i];
        const chainStart = chain[0];
        const chainEnd = chain[chain.length - 1];
        const nextStart = next[0];
        const nextEnd = next[next.length - 1];

        if (near(chainEnd, nextStart, tolerance)) {
          chain.push(...next.slice(1));
        } else if (near(chainEnd, nextEnd, tolerance)) {
          chain.push(...next.slice(0, -1).reverse());
        } else if (near(chainStart, nextEnd, tolerance)) {
          chain.unshift(...next.slice(0, -1));
        } else if (near(chainStart, nextStart, tolerance)) {
          chain.unshift(...next.slice(1).reverse());
        } else {
          continue;
        }

        pending.splice(i, 1);
        sourceCount++;
        changed = true;
        break;
      }
    }

    if (chain.length < 3) continue;
    const alreadyClosed = near(chain[0], chain[chain.length - 1], tolerance);
    if (alreadyClosed) chain.pop();
    const points = simplify(chain);

    // Many engineering PDFs intentionally leave one side of the part open
    // where the dimension leaders are drawn. DXF's closed polyline restores it.
    if (points.length >= 3) {
      candidates.push({
        points,
        sourceCount,
        impliedClose: !alreadyClosed,
      });
    }
  }
  return candidates;
}

function bounds(points) {
  const xs = points.map(point => point[0]);
  const ys = points.map(point => point[1]);
  const minX = Math.min(...xs);
  const maxX = Math.max(...xs);
  const minY = Math.min(...ys);
  const maxY = Math.max(...ys);
  return {
    minX,
    maxX,
    minY,
    maxY,
    width: maxX - minX,
    height: maxY - minY,
  };
}

function isAxisAlignedRectangle(points) {
  if (points.length !== 4) return false;
  for (let i = 0; i < points.length; i++) {
    const a = points[i];
    const b = points[(i + 1) % points.length];
    if (Math.abs(a[0] - b[0]) > 0.1 && Math.abs(a[1] - b[1]) > 0.1) {
      return false;
    }
  }
  return true;
}

function isCircleLike(points, box) {
  if (points.length < 12 || box.width <= 0 || box.height <= 0) return false;
  const aspect = box.width / box.height;
  if (aspect < 0.85 || aspect > 1.15) return false;
  const cx = (box.minX + box.maxX) / 2;
  const cy = (box.minY + box.maxY) / 2;
  const radii = points.map(point => Math.hypot(point[0] - cx, point[1] - cy));
  const mean = radii.reduce((sum, value) => sum + value, 0) / radii.length;
  const variance = radii.reduce(
    (sum, value) => sum + (value - mean) ** 2,
    0,
  ) / radii.length;
  return mean > 0 && Math.sqrt(variance) / mean < 0.08;
}

function textPosition(item) {
  return {
    x: item.transform?.[4] || 0,
    y: item.transform?.[5] || 0,
  };
}

function drawingScale(textItems) {
  const labels = [];
  const ratios = [];

  for (const item of textItems) {
    const text = String(item.str || '').trim();
    const position = textPosition(item);
    if (/^scale\s*:?\s*$/i.test(text)) labels.push(position);

    const regex = /(\d+(?:\.\d+)?)\s*:\s*(\d+(?:\.\d+)?)/g;
    let match;
    while ((match = regex.exec(text)) !== null) {
      ratios.push({
        ...position,
        left: Number(match[1]),
        right: Number(match[2]),
      });
    }
  }

  if (!ratios.length) return 1;
  let ratio = ratios[0];
  if (labels.length) {
    ratio = ratios
      .map(value => ({
        value,
        distance: Math.min(...labels.map(
          label => Math.hypot(value.x - label.x, value.y - label.y),
        )),
      }))
      .sort((a, b) => a.distance - b.distance)[0].value;
  } else if (ratios.length > 1) {
    return 1;
  }

  const scale = ratio.right / ratio.left;
  return Number.isFinite(scale) && scale >= 0.01 && scale <= 1000 ? scale : 1;
}

function profileAnchors(textItems, viewport) {
  const anchors = [];

  for (const item of textItems) {
    const raw = String(item.str || '').trim();
    if (!raw || raw !== raw.toUpperCase() || !/[A-Z]/.test(raw)) continue;
    const text = raw.replace(/\s+/g, ' ');
    const position = textPosition(item);

    // Ignore drawing-title text in the standard lower-right title block.
    if (position.x > viewport.width * 0.58 &&
        position.y < viewport.height * 0.28) {
      continue;
    }

    let weight = 0;
    if (text.includes('GLAZING')) weight = 8;
    else if (text.includes('PROFILE') || text.includes('OUTLINE')) weight = 6;
    else if (text === 'GLASS') weight = 2;
    if (weight) anchors.push({...position, weight});
  }
  return anchors;
}

function distanceToBox(point, box) {
  const dx = Math.max(box.minX - point.x, 0, point.x - box.maxX);
  const dy = Math.max(box.minY - point.y, 0, point.y - box.maxY);
  return Math.hypot(dx, dy);
}

function rankProfiles(paths, textItems, viewport) {
  const anchors = profileAnchors(textItems, viewport);
  const pageArea = viewport.width * viewport.height;

  const measured = buildProfileCandidates(paths)
    .map(candidate => ({...candidate, ...bounds(candidate.points)}))
    .filter(candidate =>
      candidate.points.length >= 4 &&
      candidate.width > viewport.width * 0.015 &&
      candidate.height > viewport.height * 0.015 &&
      candidate.width < viewport.width * 0.96 &&
      candidate.height < viewport.height * 0.96 &&
      candidate.width * candidate.height < pageArea * 0.72);

  if (!measured.length) {
    throw new Error('No usable part profile found in the PDF.');
  }

  for (const candidate of measured) {
    const area = candidate.width * candidate.height;
    const vertexCount = candidate.points.length;
    let score = Math.log1p(area) * 8;

    if (vertexCount >= 5 && vertexCount <= 80) score += 100;
    if (isAxisAlignedRectangle(candidate.points)) score -= 140;
    if (isCircleLike(candidate.points, candidate)) score -= 180;
    if (candidate.impliedClose && vertexCount >= 5) score += 20;

    for (const anchor of anchors) {
      const proximity = anchor.weight * 10000 /
        (80 + distanceToBox(anchor, candidate));
      score += proximity;

      // Profile captions are normally directly below the required view.
      if (anchor.x >= candidate.minX - candidate.width * 0.25 &&
          anchor.x <= candidate.maxX + candidate.width * 0.25 &&
          anchor.y <= candidate.minY + candidate.height * 0.2) {
        score += anchor.weight * 40;
      }
    }
    candidate.score = score;
  }

  measured.sort((a, b) => b.score - a.score);
  return measured;
}

function dxf(points) {
  const rows = [
    '0', 'SECTION', '2', 'HEADER',
    '9', '$INSUNITS', '70', '4',
    '0', 'ENDSEC',
    '0', 'SECTION', '2', 'ENTITIES',
    '0', 'LWPOLYLINE',
    '100', 'AcDbEntity',
    '8', 'OUTLINE',
    '100', 'AcDbPolyline',
    '90', String(points.length),
    '70', '1',
  ];
  for (const point of points) {
    rows.push('10', point[0].toFixed(4), '20', point[1].toFixed(4));
  }
  rows.push('0', 'ENDSEC', '0', 'EOF');
  return rows.join('\n') + '\n';
}

async function analyzePdf2d(bytes) {
  const data = bytes instanceof Uint8Array ? bytes : new Uint8Array(bytes);
  const pdf = await pdfjsLib.getDocument({data}).promise;
  const page = await pdf.getPage(1);
  const viewport = page.getViewport({scale: 1});
  const [operatorList, textContent] = await Promise.all([
    page.getOperatorList(),
    page.getTextContent(),
  ]);

  const O = pdfjsLib.OPS;
  let matrix = [1, 0, 0, 1, 0, 0];
  const stack = [];
  let active = [];
  const paths = [];

  const finish = () => {
    if (active.length >= 2) {
      const closed = near(active[0], active[active.length - 1]);
      if (closed) active.pop();
      paths.push({points: active, closed});
    }
    active = [];
  };

  for (let i = 0; i < operatorList.fnArray.length; i++) {
    const fn = operatorList.fnArray[i];
    const args = operatorList.argsArray[i] || [];

    if (fn === O.save) {
      stack.push(matrix.slice());
    } else if (fn === O.restore) {
      matrix = stack.pop() || [1, 0, 0, 1, 0, 0];
    } else if (fn === O.transform) {
      matrix = multiply(matrix, args);
    } else if (fn === O.constructPath) {
      const operations = args[0];
      const coordinates = args[1];
      let cursor = 0;

      for (const operation of operations) {
        if (operation === O.moveTo) {
          finish();
          active.push(apply(
            matrix,
            coordinates[cursor++],
            coordinates[cursor++],
          ));
        } else if (operation === O.lineTo) {
          active.push(apply(
            matrix,
            coordinates[cursor++],
            coordinates[cursor++],
          ));
        } else if (operation === O.curveTo) {
          const p0 = active[active.length - 1];
          const p1 = apply(matrix, coordinates[cursor++], coordinates[cursor++]);
          const p2 = apply(matrix, coordinates[cursor++], coordinates[cursor++]);
          const p3 = apply(matrix, coordinates[cursor++], coordinates[cursor++]);
          if (p0) cubic(active, p0, p1, p2, p3);
        } else if (operation === O.curveTo2) {
          const p0 = active[active.length - 1];
          const p2 = apply(matrix, coordinates[cursor++], coordinates[cursor++]);
          const p3 = apply(matrix, coordinates[cursor++], coordinates[cursor++]);
          if (p0) cubic(active, p0, p0, p2, p3);
        } else if (operation === O.curveTo3) {
          const p0 = active[active.length - 1];
          const p1 = apply(matrix, coordinates[cursor++], coordinates[cursor++]);
          const p3 = apply(matrix, coordinates[cursor++], coordinates[cursor++]);
          if (p0) cubic(active, p0, p1, p3, p3);
        } else if (operation === O.rectangle) {
          const x = coordinates[cursor++];
          const y = coordinates[cursor++];
          const width = coordinates[cursor++];
          const height = coordinates[cursor++];
          active.push(
            apply(matrix, x, y),
            apply(matrix, x + width, y),
            apply(matrix, x + width, y + height),
            apply(matrix, x, y + height),
            apply(matrix, x, y),
          );
        } else if (operation === O.closePath && active.length) {
          active.push(active[0]);
        }
      }
    } else if (
      fn === O.stroke ||
      fn === O.closeStroke ||
      fn === O.fill ||
      fn === O.eoFill ||
      fn === O.fillStroke ||
      fn === O.eoFillStroke ||
      fn === O.closeFillStroke ||
      fn === O.closeEOFillStroke ||
      fn === O.endPath
    ) {
      finish();
    }
  }
  finish();

  const shapes = rankProfiles(paths, textContent.items, viewport);
  const scale = drawingScale(textContent.items);
  const mmPerPoint = 25.4 / 72 * (page.userUnit || 1) * scale;
  const profiles = shapes.slice(0, 10).map((shape, index) => {
    const points = shape.points.map(point => [
      (point[0] - shape.minX) * mmPerPoint,
      (point[1] - shape.minY) * mmPerPoint,
    ]);
    return {
      id: index,
      suggested: index === 0,
      inferredClosure: shape.impliedClose,
      vertexCount: points.length,
      width: shape.width * mmPerPoint,
      height: shape.height * mmPerPoint,
      points,
    };
  });
  return {drawingScale: scale, profiles};
}

window.pdfAnalyze2d = async function(bytes) {
  const analysis = await analyzePdf2d(bytes);
  return JSON.stringify(analysis);
};

window.pdfToDxf2d = async function(bytes) {
  const analysis = await analyzePdf2d(bytes);
  if (!analysis.profiles.length) {
    throw new Error('No usable part profile found in the PDF.');
  }
  return dxf(analysis.profiles[0].points);
};

window.pdfToDxf2dCallback = function(bytes, onSuccess, onError) {
  window.pdfToDxf2d(bytes)
    .then(result => onSuccess(result))
    .catch(error => onError(
      error && error.message ? error.message : String(error),
    ));
};

window.pdfAnalyze2dCallback = function(bytes, onSuccess, onError) {
  window.pdfAnalyze2d(bytes)
    .then(result => onSuccess(result))
    .catch(error => onError(
      error && error.message ? error.message : String(error),
    ));
};

function addRasterSegment(segments, x1, y1, x2, y2) {
  segments.push({
    a: `${x1},${y1}`,
    b: `${x2},${y2}`,
    pa: [x1 / 2, y1 / 2],
    pb: [x2 / 2, y2 / 2],
    used: false,
  });
}

function marchingSegments(labels, wanted, width, height) {
  const segments = [];
  for (let y = 0; y < height - 1; y++) {
    for (let x = 0; x < width - 1; x++) {
      const topLeft = labels[y * width + x] === wanted ? 1 : 0;
      const topRight = labels[y * width + x + 1] === wanted ? 2 : 0;
      const bottomRight =
        labels[(y + 1) * width + x + 1] === wanted ? 4 : 0;
      const bottomLeft = labels[(y + 1) * width + x] === wanted ? 8 : 0;
      const state = topLeft | topRight | bottomRight | bottomLeft;
      if (state === 0 || state === 15) continue;

      const top = [2 * x + 1, 2 * y];
      const right = [2 * x + 2, 2 * y + 1];
      const bottom = [2 * x + 1, 2 * y + 2];
      const left = [2 * x, 2 * y + 1];
      const add = (a, b) => addRasterSegment(
        segments,
        a[0],
        a[1],
        b[0],
        b[1],
      );

      if (state === 1 || state === 14) add(left, top);
      else if (state === 2 || state === 13) add(top, right);
      else if (state === 3 || state === 12) add(left, right);
      else if (state === 4 || state === 11) add(right, bottom);
      else if (state === 6 || state === 9) add(top, bottom);
      else if (state === 7 || state === 8) add(left, bottom);
      else if (state === 5) {
        add(left, top);
        add(right, bottom);
      } else if (state === 10) {
        add(top, right);
        add(bottom, left);
      }
    }
  }
  return segments;
}

function stitchRasterSegments(segments) {
  const links = new Map();
  const attach = (key, index) => {
    if (!links.has(key)) links.set(key, []);
    links.get(key).push(index);
  };
  segments.forEach((segment, index) => {
    attach(segment.a, index);
    attach(segment.b, index);
  });

  const paths = [];
  for (let seed = 0; seed < segments.length; seed++) {
    if (segments[seed].used) continue;
    const first = segments[seed];
    first.used = true;
    const path = [first.pa, first.pb];
    const startKey = first.a;
    let currentKey = first.b;

    for (let guard = 0; guard < segments.length + 2; guard++) {
      if (currentKey === startKey) break;
      const nextIndex = (links.get(currentKey) || [])
        .find(index => !segments[index].used);
      if (nextIndex === undefined) break;
      const next = segments[nextIndex];
      next.used = true;
      if (next.a === currentKey) {
        path.push(next.pb);
        currentKey = next.b;
      } else {
        path.push(next.pa);
        currentKey = next.a;
      }
    }

    if (path.length >= 4 && currentKey === startKey) {
      path.pop();
      paths.push(path);
    }
  }
  return paths;
}

function pointLineDistance(point, start, end) {
  const dx = end[0] - start[0];
  const dy = end[1] - start[1];
  if (dx === 0 && dy === 0) return distance(point, start);
  const t = Math.max(0, Math.min(
    1,
    ((point[0] - start[0]) * dx + (point[1] - start[1]) * dy) /
      (dx * dx + dy * dy),
  ));
  return Math.hypot(
    point[0] - (start[0] + t * dx),
    point[1] - (start[1] + t * dy),
  );
}

function simplifyOpenRaster(points, epsilon) {
  if (points.length <= 2) return points.slice();
  let farthest = 0;
  let farthestDistance = 0;
  for (let i = 1; i < points.length - 1; i++) {
    const value = pointLineDistance(
      points[i],
      points[0],
      points[points.length - 1],
    );
    if (value > farthestDistance) {
      farthest = i;
      farthestDistance = value;
    }
  }
  if (farthestDistance <= epsilon) {
    return [points[0], points[points.length - 1]];
  }
  const left = simplifyOpenRaster(points.slice(0, farthest + 1), epsilon);
  const right = simplifyOpenRaster(points.slice(farthest), epsilon);
  return left.slice(0, -1).concat(right);
}

function simplifyClosedRaster(points, epsilon) {
  if (points.length <= 4) return points.slice();
  let split = 1;
  let farthest = 0;
  for (let i = 1; i < points.length; i++) {
    const value = distance(points[0], points[i]);
    if (value > farthest) {
      farthest = value;
      split = i;
    }
  }
  const first = simplifyOpenRaster(points.slice(0, split + 1), epsilon);
  const second = simplifyOpenRaster(
    points.slice(split).concat([points[0]]),
    epsilon,
  );
  const combined = first.slice(0, -1).concat(second.slice(0, -1));
  return simplify(combined);
}

function enclosedRasterRegions(mask, width, height) {
  const size = width * height;
  const outside = new Uint8Array(size);
  const queue = new Int32Array(size);
  let head = 0;
  let tail = 0;
  const enqueueOutside = index => {
    if (!mask[index] && !outside[index]) {
      outside[index] = 1;
      queue[tail++] = index;
    }
  };
  for (let x = 0; x < width; x++) {
    enqueueOutside(x);
    enqueueOutside((height - 1) * width + x);
  }
  for (let y = 0; y < height; y++) {
    enqueueOutside(y * width);
    enqueueOutside(y * width + width - 1);
  }
  while (head < tail) {
    const index = queue[head++];
    const x = index % width;
    const y = Math.floor(index / width);
    if (x > 0) enqueueOutside(index - 1);
    if (x + 1 < width) enqueueOutside(index + 1);
    if (y > 0) enqueueOutside(index - width);
    if (y + 1 < height) enqueueOutside(index + width);
  }

  const labels = new Int32Array(size);
  const regions = [];
  let label = 0;
  for (let seed = 0; seed < size; seed++) {
    if (mask[seed] || outside[seed] || labels[seed]) continue;
    label++;
    head = 0;
    tail = 0;
    queue[tail++] = seed;
    labels[seed] = label;
    let area = 0;
    let minX = width;
    let maxX = 0;
    let minY = height;
    let maxY = 0;
    while (head < tail) {
      const index = queue[head++];
      const x = index % width;
      const y = Math.floor(index / width);
      area++;
      minX = Math.min(minX, x);
      maxX = Math.max(maxX, x);
      minY = Math.min(minY, y);
      maxY = Math.max(maxY, y);
      const visit = next => {
        if (!mask[next] && !outside[next] && !labels[next]) {
          labels[next] = label;
          queue[tail++] = next;
        }
      };
      if (x > 0) visit(index - 1);
      if (x + 1 < width) visit(index + 1);
      if (y > 0) visit(index - width);
      if (y + 1 < height) visit(index + width);
    }
    regions.push({label, area, minX, maxX, minY, maxY});
  }
  return {labels, regions};
}

async function analyzeClipboardBlob(blob) {
  const bitmap = await createImageBitmap(blob);
  const maximum = 1600;
  const scale = Math.min(1, maximum / Math.max(bitmap.width, bitmap.height));
  const width = Math.max(1, Math.round(bitmap.width * scale));
  const height = Math.max(1, Math.round(bitmap.height * scale));
  const canvas = document.createElement('canvas');
  canvas.width = width;
  canvas.height = height;
  const context = canvas.getContext('2d', {willReadFrequently: true});
  context.fillStyle = '#ffffff';
  context.fillRect(0, 0, width, height);
  context.drawImage(bitmap, 0, 0, width, height);
  bitmap.close();

  const rgba = context.getImageData(0, 0, width, height).data;
  const dark = new Uint8Array(width * height);
  for (let index = 0; index < dark.length; index++) {
    const offset = index * 4;
    const luminance =
      rgba[offset] * 0.299 + rgba[offset + 1] * 0.587 +
      rgba[offset + 2] * 0.114;
    if (rgba[offset + 3] > 30 && luminance < 180) dark[index] = 1;
  }

  // Close one-pixel gaps caused by anti-aliasing when copied from a PDF.
  const closed = dark.slice();
  for (let y = 1; y < height - 1; y++) {
    for (let x = 1; x < width - 1; x++) {
      const index = y * width + x;
      if (!dark[index]) continue;
      closed[index - 1] = 1;
      closed[index + 1] = 1;
      closed[index - width] = 1;
      closed[index + width] = 1;
    }
  }

  const result = enclosedRasterRegions(closed, width, height);
  const minimumArea = Math.max(200, width * height * 0.0008);
  const candidates = result.regions
    .filter(region =>
      region.area >= minimumArea &&
      region.maxX - region.minX >= 20 &&
      region.maxY - region.minY >= 20)
    .sort((a, b) => b.area - a.area)
    .slice(0, 8)
    .map(region => {
      const segments = marchingSegments(
        result.labels,
        region.label,
        width,
        height,
      );
      const paths = stitchRasterSegments(segments)
        .sort((a, b) => b.length - a.length);
      if (!paths.length) return null;
      const raw = paths[0];
      const diagonal = Math.hypot(
        region.maxX - region.minX,
        region.maxY - region.minY,
      );
      const points = simplifyClosedRaster(
        raw,
        Math.max(1.25, diagonal * 0.003),
      );
      if (points.length < 3) return null;
      const box = bounds(points);
      return {
        points: points.map(point => [
          point[0] - box.minX,
          box.maxY - point[1],
        ]),
        width: box.width,
        height: box.height,
        score: region.area,
      };
    })
    .filter(candidate => candidate !== null)
    .sort((a, b) => b.score - a.score);

  if (!candidates.length) {
    throw new Error(
      'لم أجد محيطًا مغلقًا. انسخ الرسمة وحدها بخلفية بيضاء ثم حاول مرة أخرى.',
    );
  }

  return {
    sourceKind: 'clipboardImage',
    drawingScale: 1,
    profiles: candidates.map((candidate, index) => ({
      id: index,
      suggested: index === 0,
      inferredClosure: false,
      vertexCount: candidate.points.length,
      width: candidate.width,
      height: candidate.height,
      points: candidate.points,
    })),
  };
}

let tesseractLoader;

function loadTesseract() {
  if (window.Tesseract) return Promise.resolve(window.Tesseract);
  if (tesseractLoader) return tesseractLoader;
  tesseractLoader = new Promise((resolve, reject) => {
    const script = document.createElement('script');
    script.src =
      'https://cdn.jsdelivr.net/npm/tesseract.js@5/dist/tesseract.min.js';
    script.async = true;
    script.onload = () => resolve(window.Tesseract);
    script.onerror = () => reject(new Error('تعذر تحميل قارئ الأرقام.'));
    document.head.appendChild(script);
  });
  return tesseractLoader;
}

async function rotateImageBlobClockwise(blob) {
  const bitmap = await createImageBitmap(blob);
  const canvas = document.createElement('canvas');
  canvas.width = bitmap.height;
  canvas.height = bitmap.width;
  const context = canvas.getContext('2d');
  context.fillStyle = '#ffffff';
  context.fillRect(0, 0, canvas.width, canvas.height);
  context.translate(canvas.width, 0);
  context.rotate(Math.PI / 2);
  context.drawImage(bitmap, 0, 0);
  const originalWidth = bitmap.width;
  const originalHeight = bitmap.height;
  bitmap.close();
  const rotated = await new Promise((resolve, reject) => {
    canvas.toBlob(
      value => value ? resolve(value) : reject(new Error('تعذر تدوير الصورة.')),
      'image/png',
    );
  });
  return {blob: rotated, originalWidth, originalHeight};
}

function numericWordsFromTsv(tsv, orientation, originalWidth, originalHeight) {
  if (!tsv) return [];
  const readings = [];
  const rows = tsv.split(/\r?\n/);
  for (let index = 1; index < rows.length; index++) {
    const columns = rows[index].split('\t');
    if (columns.length < 12) continue;
    const confidence = Number(columns[10]);
    const raw = columns.slice(11).join('\t').trim().replace(',', '.');
    if (confidence < 40 || !/^-?\d+(?:\.\d+)?$/.test(raw)) continue;
    const left = Number(columns[6]);
    const top = Number(columns[7]);
    const width = Number(columns[8]);
    const height = Number(columns[9]);
    let x = left + width / 2;
    let y = top + height / 2;
    if (orientation === 'rotated') {
      const rotatedX = x;
      x = y;
      y = originalHeight - rotatedX;
    }
    readings.push({
      value: raw,
      confidence,
      x: x / originalWidth,
      y: y / originalHeight,
    });
  }
  return readings;
}

function mergeExactOcrReadings(readings) {
  const merged = [];
  for (const reading of readings) {
    const duplicate = merged.find(item =>
      item.value === reading.value &&
      Math.hypot(item.x - reading.x, item.y - reading.y) < 0.06);
    if (!duplicate) {
      merged.push(reading);
    } else if (reading.confidence > duplicate.confidence) {
      Object.assign(duplicate, reading);
    }
  }
  return merged.map(reading => ({
    value: reading.value,
    confidence: reading.confidence,
  }));
}

async function readWrittenDimensions(blob) {
  const Tesseract = await loadTesseract();
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
    });
    const originalBitmap = await createImageBitmap(blob);
    const originalWidth = originalBitmap.width;
    const originalHeight = originalBitmap.height;
    originalBitmap.close();
    const original = await worker.recognize(blob, {}, {tsv: true});
    const rotatedImage = await rotateImageBlobClockwise(blob);
    const rotated = await worker.recognize(
      rotatedImage.blob,
      {},
      {tsv: true},
    );
    return mergeExactOcrReadings([
      ...numericWordsFromTsv(
        original.data.tsv,
        'original',
        originalWidth,
        originalHeight,
      ),
      ...numericWordsFromTsv(
        rotated.data.tsv,
        'rotated',
        originalWidth,
        originalHeight,
      ),
    ]);
  } finally {
    await worker.terminate();
  }
}

window.drawingImageAnalyze2d = async function(bytes, contentType) {
  const data = bytes instanceof Uint8Array ? bytes : new Uint8Array(bytes);
  const blob = new Blob([data], {
    type: contentType || 'image/png',
  });
  const dimensionReadings = await readWrittenDimensions(blob);
  let analysis;
  try {
    analysis = await analyzeClipboardBlob(blob);
  } catch (_) {
    analysis = {drawingScale: 1, profiles: []};
  }
  analysis.sourceKind = 'imageOcr';
  analysis.dimensionReadings = dimensionReadings;
  return JSON.stringify(analysis);
};

window.drawingImageAnalyze2dCallback = function(
  bytes,
  contentType,
  onSuccess,
  onError,
) {
  window.drawingImageAnalyze2d(bytes, contentType)
    .then(result => onSuccess(result))
    .catch(error => onError(
      error && error.message ? error.message : String(error),
    ));
};

window.clipboardImageAnalyze2d = async function() {
  if (!navigator.clipboard || !navigator.clipboard.read) {
    throw new Error('المتصفح لا يسمح بقراءة الصور من الحافظة.');
  }
  const items = await navigator.clipboard.read();
  for (const item of items) {
    const imageType = item.types.find(type => type.startsWith('image/'));
    if (imageType) {
      const blob = await item.getType(imageType);
      return JSON.stringify(await analyzeClipboardBlob(blob));
    }
  }
  throw new Error('لا توجد صورة في الحافظة. انسخ الرسمة أولًا ثم اضغط لصق.');
};

window.clipboardImageAnalyze2dCallback = function(onSuccess, onError) {
  window.clipboardImageAnalyze2d()
    .then(result => onSuccess(result))
    .catch(error => onError(
      error && error.message ? error.message : String(error),
    ));
};
