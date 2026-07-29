import * as pdfjsLib from 'https://cdnjs.cloudflare.com/ajax/libs/pdf.js/4.10.38/pdf.min.mjs';

pdfjsLib.GlobalWorkerOptions.workerSrc =
  'https://cdnjs.cloudflare.com/ajax/libs/pdf.js/4.10.38/pdf.worker.min.mjs';

const apply = (m, x, y) => [
  m[0] * x + m[2] * y + m[4],
  m[1] * x + m[3] * y + m[5],
];
const multiply = (a, b) => [
  a[0] * b[0] + a[2] * b[1], a[1] * b[0] + a[3] * b[1],
  a[0] * b[2] + a[2] * b[3], a[1] * b[2] + a[3] * b[3],
  a[0] * b[4] + a[2] * b[5] + a[4],
  a[1] * b[4] + a[3] * b[5] + a[5],
];
const near = (a, b) => Math.hypot(a[0] - b[0], a[1] - b[1]) < 0.75;

function cubic(points, p0, p1, p2, p3) {
  for (let i = 1; i <= 16; i++) {
    const t = i / 16, u = 1 - t;
    points.push([
      u*u*u*p0[0] + 3*u*u*t*p1[0] + 3*u*t*t*p2[0] + t*t*t*p3[0],
      u*u*u*p0[1] + 3*u*u*t*p1[1] + 3*u*t*t*p2[1] + t*t*t*p3[1],
    ]);
  }
}

function joinedClosedPaths(paths, tolerance = 1.5) {
  const closed = paths.filter(p => p.closed && p.points.length >= 3)
    .map(p => ({points:p.points, closed:true, sourceCount:1}));
  const pending = paths.filter(p => !p.closed && p.points.length >= 2)
    .map(p => p.points.slice());
  while (pending.length) {
    let chain = pending.shift(), sourceCount = 1, changed = true;
    while (changed) {
      changed = false;
      for (let i=0; i<pending.length; i++) {
        const next=pending[i], cs=chain[0], ce=chain[chain.length-1];
        if (near(ce,next[0]) || Math.hypot(ce[0]-next[0][0],ce[1]-next[0][1]) <= tolerance) {
          chain.push(...next.slice(1)); pending.splice(i,1); sourceCount++; changed=true; break;
        }
        if (near(ce,next[next.length-1]) || Math.hypot(ce[0]-next[next.length-1][0],ce[1]-next[next.length-1][1]) <= tolerance) {
          chain.push(...next.slice(0,-1).reverse()); pending.splice(i,1); sourceCount++; changed=true; break;
        }
        if (near(cs,next[next.length-1]) || Math.hypot(cs[0]-next[next.length-1][0],cs[1]-next[next.length-1][1]) <= tolerance) {
          chain.unshift(...next.slice(0,-1)); pending.splice(i,1); sourceCount++; changed=true; break;
        }
        if (near(cs,next[0]) || Math.hypot(cs[0]-next[0][0],cs[1]-next[0][1]) <= tolerance) {
          chain.unshift(...next.slice(1).reverse()); pending.splice(i,1); sourceCount++; changed=true; break;
        }
      }
    }
    if (chain.length >= 3 && Math.hypot(chain[0][0]-chain[chain.length-1][0],chain[0][1]-chain[chain.length-1][1]) <= tolerance) {
      chain.pop();
      closed.push({points:chain, closed:true, sourceCount});
    }
  }
  return closed;
}

function dxf(points) {
  const rows = ['0','SECTION','2','HEADER','9','$INSUNITS','70','4','0','ENDSEC','0','SECTION','2','ENTITIES','0','LWPOLYLINE','100','AcDbEntity','8','OUTLINE','100','AcDbPolyline','90',String(points.length),'70','1'];
  for (const p of points) rows.push('10', p[0].toFixed(4), '20', p[1].toFixed(4));
  rows.push('0','ENDSEC','0','EOF');
  return rows.join('\n') + '\n';
}

window.pdfToDxf2d = async function(bytes) {
  const data = bytes instanceof Uint8Array ? bytes : new Uint8Array(bytes);
  const pdf = await pdfjsLib.getDocument({data}).promise;
  const page = await pdf.getPage(1);
  const viewport = page.getViewport({scale: 1});
  const list = await page.getOperatorList();
  const O = pdfjsLib.OPS;
  let matrix = [1,0,0,1,0,0], stack = [], active = [], paths = [];
  const finish = () => {
    if (active.length >= 2) {
      const closed = near(active[0], active[active.length - 1]);
      if (closed) active.pop();
      paths.push({points: active, closed});
    }
    active = [];
  };
  for (let i = 0; i < list.fnArray.length; i++) {
    const fn = list.fnArray[i], args = list.argsArray[i] || [];
    if (fn === O.save) stack.push(matrix.slice());
    else if (fn === O.restore) matrix = stack.pop() || [1,0,0,1,0,0];
    else if (fn === O.transform) matrix = multiply(matrix, args);
    else if (fn === O.constructPath) {
      const ops = args[0], coords = args[1]; let k = 0;
      for (const op of ops) {
        if (op === O.moveTo) { if (active.length >= 3) finish(); active.push(apply(matrix, coords[k++], coords[k++])); }
        else if (op === O.lineTo) active.push(apply(matrix, coords[k++], coords[k++]));
        else if (op === O.curveTo) {
          const p0 = active[active.length - 1], p1 = apply(matrix, coords[k++], coords[k++]), p2 = apply(matrix, coords[k++], coords[k++]), p3 = apply(matrix, coords[k++], coords[k++]);
          if (p0) cubic(active, p0, p1, p2, p3);
        } else if (op === O.rectangle) {
          const x=coords[k++], y=coords[k++], w=coords[k++], h=coords[k++];
          active.push(apply(matrix,x,y),apply(matrix,x+w,y),apply(matrix,x+w,y+h),apply(matrix,x,y+h),apply(matrix,x,y));
        } else if (op === O.closePath && active.length) active.push(active[0]);
      }
    } else if (fn === O.stroke || fn === O.closeStroke || fn === O.fill || fn === O.eoFill || fn === O.fillStroke || fn === O.eoFillStroke || fn === O.closeFillStroke || fn === O.closeEOFillStroke || fn === O.endPath) finish();
  }
  finish();
  const measured = joinedClosedPaths(paths).map(p => {
    const xs=p.points.map(q=>q[0]), ys=p.points.map(q=>q[1]);
    return {...p,minX:Math.min(...xs),maxX:Math.max(...xs),minY:Math.min(...ys),maxY:Math.max(...ys)};
  }).filter(p => !((p.maxX-p.minX)>viewport.width*.95 && (p.maxY-p.minY)>viewport.height*.95));
  if (!measured.length) throw new Error('No closed profile found in the PDF.');
  const joined = measured.filter(p => p.sourceCount > 1);
  const candidates = joined.length ? joined : measured;
  candidates.sort((a,b)=>(b.maxX-b.minX)*(b.maxY-b.minY)-(a.maxX-a.minX)*(a.maxY-a.minY));
  const shape=candidates[0];
  const mmPerPoint = 25.4 / 72 * (page.userUnit || 1);
  const points=shape.points.map(p=>[
    (p[0]-shape.minX)*mmPerPoint,
    (p[1]-shape.minY)*mmPerPoint,
  ]);
  return dxf(points);
};

window.pdfToDxf2dCallback = function(bytes, onSuccess, onError) {
  window.pdfToDxf2d(bytes)
    .then(result => onSuccess(result))
    .catch(error => onError(error && error.message ? error.message : String(error)));
};

