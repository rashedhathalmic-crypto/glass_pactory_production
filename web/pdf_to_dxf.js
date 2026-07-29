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

function chooseProfile(paths, textItems, viewport) {
  const anchors = profileAnchors(textItems, viewport);
  const pageArea = viewport.width * viewport.height;

  const measured = buildProfileCandidates(paths)
    .map(candidate => ({...candidate, ...bounds(candidate.points)}))
    .filter(candidate =>
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
  return measured[0];
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

window.pdfToDxf2d = async function(bytes) {
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

  const shape = chooseProfile(paths, textContent.items, viewport);
  const scale = drawingScale(textContent.items);
  const mmPerPoint = 25.4 / 72 * (page.userUnit || 1) * scale;
  const points = shape.points.map(point => [
    (point[0] - shape.minX) * mmPerPoint,
    (point[1] - shape.minY) * mmPerPoint,
  ]);
  return dxf(points);
};

window.pdfToDxf2dCallback = function(bytes, onSuccess, onError) {
  window.pdfToDxf2d(bytes)
    .then(result => onSuccess(result))
    .catch(error => onError(
      error && error.message ? error.message : String(error),
    ));
};
