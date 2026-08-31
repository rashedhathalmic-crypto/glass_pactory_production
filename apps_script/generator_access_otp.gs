const OWNER_EMAIL = 'rashedhathalmic@gmail.com';
const FIREBASE_WEB_API_KEY = 'AIzaSyBqCAatF7QEiS3SwtJULyNRVrjxAvF6phI';
const OTP_TTL_SECONDS = 600;
const MAX_OTP_ATTEMPTS = 5;
const MAX_OTP_REQUESTS_PER_15_MINUTES = 5;
const SERVICE_VERSION = 'email-otp-v2';

function doGet(e) {
  const action = String((e && e.parameter && e.parameter.action) || 'health');
  let result;

  if (action === 'health') {
    result = {
      status: 'healthy',
      ok: true,
      version: SERVICE_VERSION,
      owner: OWNER_EMAIL,
    };
  } else if (action === 'poll') {
    result = pollRequest_(e.parameter || {});
  } else {
    result = {status: 'error', message: 'Unsupported action.'};
  }

  const storageKey = String((e && e.parameter && e.parameter.storageKey) || '');
  return storageKey ? scriptResponse_(storageKey, result) : jsonResponse_(result);
}

function doPost(e) {
  const params = (e && e.parameter) || {};
  const action = String(params.action || '');
  let result;

  try {
    if (action === 'requestOtp') {
      result = requestOtp_(params);
    } else if (action === 'verifyOtp') {
      result = verifyOtp_(params);
    } else {
      result = {status: 'error', message: 'Unsupported action.'};
    }
  } catch (error) {
    console.error(error && error.stack ? error.stack : error);
    result = {
      status: 'error',
      message: 'OTP service failed to process the request.',
    };
  }

  return jsonResponse_(result);
}

function requestOtp_(params) {
  const requestId = cleanRequestId_(params.requestId);
  const pollToken = cleanPollToken_(params.pollToken);
  const idToken = String(params.idToken || '');
  const requesterName = cleanText_(params.requesterName, 80);
  const tool = cleanText_(params.tool, 120);
  const device = cleanText_(params.device, 500);

  if (!requestId || !pollToken || !idToken) {
    return {status: 'error', message: 'Invalid OTP request.'};
  }

  const auth = verifyFirebaseIdToken_(idToken);
  if (!auth.ok || auth.email.toLowerCase() !== OWNER_EMAIL.toLowerCase()) {
    return {status: 'unauthorized', message: 'Password session was not accepted.'};
  }

  const rate = consumeRequestRate_(auth.uid);
  if (!rate.allowed) {
    return {
      status: 'rate_limited',
      message: 'Too many OTP requests. Try again later.',
      retryAfter: rate.retryAfter,
    };
  }

  const cache = CacheService.getScriptCache();
  const existing = cache.get(requestKey_(requestId));
  if (existing) {
    return {status: 'error', message: 'Duplicate OTP request.'};
  }

  const now = Date.now();
  const otp = generateOtp_();
  const expiresAt = now + OTP_TTL_SECONDS * 1000;
  const record = {
    version: SERVICE_VERSION,
    uid: auth.uid,
    email: auth.email,
    pollHash: secureHash_(pollToken),
    otpHash: secureHash_(requestId + '|' + otp),
    status: 'otp_sent',
    attempts: 0,
    createdAt: now,
    expiresAt: expiresAt,
    requesterName: requesterName,
    tool: tool,
    device: device,
    lastAttemptId: '',
    message: 'OTP sent to owner email.',
  };

  saveRecord_(requestId, record);

  try {
    sendOtpEmail_(otp, record);
  } catch (error) {
    record.status = 'error';
    record.message = 'Failed to send OTP email.';
    saveRecord_(requestId, record);
    console.error(error && error.stack ? error.stack : error);
    return {status: 'error', message: record.message};
  }

  return {
    status: 'otp_sent',
    expiresAt: expiresAt,
    message: 'OTP sent to owner email.',
  };
}

function verifyOtp_(params) {
  const requestId = cleanRequestId_(params.requestId);
  const pollToken = cleanPollToken_(params.pollToken);
  const otp = String(params.otp || '').trim();
  const idToken = String(params.idToken || '');
  const attemptId = cleanAttemptId_(params.attemptId);

  if (!requestId || !pollToken || !/^\d{6}$/.test(otp) || !idToken || !attemptId) {
    return {status: 'error', message: 'Invalid OTP verification request.'};
  }

  const record = loadRecord_(requestId);
  if (!record) {
    return {status: 'expired', message: 'OTP request expired.'};
  }
  if (!constantEquals_(record.pollHash, secureHash_(pollToken))) {
    return {status: 'unauthorized', message: 'OTP request token is invalid.'};
  }

  if (Date.now() >= Number(record.expiresAt || 0)) {
    record.status = 'expired';
    record.message = 'OTP expired.';
    record.lastAttemptId = attemptId;
    saveRecord_(requestId, record);
    return {status: 'expired', message: record.message};
  }

  const auth = verifyFirebaseIdToken_(idToken);
  if (!auth.ok ||
      auth.uid !== record.uid ||
      auth.email.toLowerCase() !== OWNER_EMAIL.toLowerCase()) {
    record.status = 'unauthorized';
    record.message = 'Password session no longer matches this OTP request.';
    record.lastAttemptId = attemptId;
    saveRecord_(requestId, record);
    return {status: 'unauthorized', message: record.message};
  }

  if (Number(record.attempts || 0) >= MAX_OTP_ATTEMPTS) {
    record.status = 'locked';
    record.message = 'OTP request locked.';
    record.lastAttemptId = attemptId;
    saveRecord_(requestId, record);
    return {status: 'locked', message: record.message};
  }

  const expected = record.otpHash;
  const supplied = secureHash_(requestId + '|' + otp);
  record.lastAttemptId = attemptId;

  if (!constantEquals_(expected, supplied)) {
    record.attempts = Number(record.attempts || 0) + 1;
    const remaining = Math.max(0, MAX_OTP_ATTEMPTS - record.attempts);
    record.status = remaining > 0 ? 'invalid_otp' : 'locked';
    record.message = remaining > 0 ? 'Incorrect OTP.' : 'OTP request locked.';
    saveRecord_(requestId, record);
    return {
      status: record.status,
      message: record.message,
      attemptsRemaining: remaining,
    };
  }

  record.status = 'approved';
  record.message = 'Password and OTP verified.';
  record.otpHash = '';
  record.approvedAt = Date.now();
  saveRecord_(requestId, record);

  return {
    status: 'approved',
    message: record.message,
  };
}

function pollRequest_(params) {
  const requestId = cleanRequestId_(params.id);
  const pollToken = cleanPollToken_(params.token);
  const expectedAttempt = cleanAttemptId_(params.attempt || '');

  if (!requestId || !pollToken) {
    return {status: 'invalid'};
  }

  const record = loadRecord_(requestId);
  if (!record) {
    return {status: 'invalid'};
  }
  if (!constantEquals_(record.pollHash, secureHash_(pollToken))) {
    return {status: 'unauthorized'};
  }

  if (Date.now() >= Number(record.expiresAt || 0) && record.status !== 'approved') {
    return {status: 'expired', message: 'OTP expired.'};
  }

  if (expectedAttempt && record.lastAttemptId !== expectedAttempt) {
    return {status: 'pending'};
  }

  return {
    status: record.status || 'pending',
    message: record.message || '',
    expiresAt: Number(record.expiresAt || 0),
    attemptsRemaining: Math.max(
      0,
      MAX_OTP_ATTEMPTS - Number(record.attempts || 0)
    ),
  };
}

function verifyFirebaseIdToken_(idToken) {
  try {
    const response = UrlFetchApp.fetch(
      'https://identitytoolkit.googleapis.com/v1/accounts:lookup?key=' +
        encodeURIComponent(FIREBASE_WEB_API_KEY),
      {
        method: 'post',
        contentType: 'application/json',
        payload: JSON.stringify({idToken: idToken}),
        muteHttpExceptions: true,
      }
    );

    if (response.getResponseCode() !== 200) {
      return {ok: false};
    }

    const payload = JSON.parse(response.getContentText() || '{}');
    const user = payload.users && payload.users[0];
    if (!user || !user.localId || !user.email) {
      return {ok: false};
    }

    return {
      ok: true,
      uid: String(user.localId),
      email: String(user.email),
    };
  } catch (error) {
    console.error(error && error.stack ? error.stack : error);
    return {ok: false};
  }
}

function consumeRequestRate_(uid) {
  const lock = LockService.getScriptLock();
  lock.waitLock(5000);
  try {
    const cache = CacheService.getScriptCache();
    const key = 'rate:' + secureHash_(uid).slice(0, 32);
    const raw = cache.get(key);
    let data = raw ? JSON.parse(raw) : {count: 0, startedAt: Date.now()};
    const age = Date.now() - Number(data.startedAt || 0);
    if (age >= 15 * 60 * 1000) {
      data = {count: 0, startedAt: Date.now()};
    }

    if (Number(data.count || 0) >= MAX_OTP_REQUESTS_PER_15_MINUTES) {
      const retryAfter = Math.max(
        1,
        Math.ceil((15 * 60 * 1000 - age) / 1000)
      );
      return {allowed: false, retryAfter: retryAfter};
    }

    data.count = Number(data.count || 0) + 1;
    cache.put(key, JSON.stringify(data), 15 * 60);
    return {allowed: true};
  } finally {
    lock.releaseLock();
  }
}

function sendOtpEmail_(otp, record) {
  const subject = 'Glass CNC Tools - Login OTP: ' + otp;
  const text = [
    'A login attempt is waiting for your approval.',
    '',
    'OTP: ' + otp,
    'Expires in: 10 minutes',
    'User: ' + (record.requesterName || '-'),
    'Tool: ' + (record.tool || '-'),
    'Device: ' + (record.device || '-'),
    '',
    'If this was not you, do not share the code.',
  ].join('\n');

  const html =
    '<div style="font-family:Arial,sans-serif;max-width:560px">' +
    '<h2>Glass CNC Tools</h2>' +
    '<p>A login attempt is waiting for your approval.</p>' +
    '<div style="font-size:34px;font-weight:700;letter-spacing:8px;' +
    'padding:16px 0">' + otp + '</div>' +
    '<p><b>Expires:</b> 10 minutes</p>' +
    '<p><b>User:</b> ' + escapeHtml_(record.requesterName || '-') + '</p>' +
    '<p><b>Tool:</b> ' + escapeHtml_(record.tool || '-') + '</p>' +
    '<p><b>Device:</b> ' + escapeHtml_(record.device || '-') + '</p>' +
    '<p style="color:#b00020"><b>If this was not you, do not share the code.</b></p>' +
    '</div>';

  MailApp.sendEmail({
    to: OWNER_EMAIL,
    subject: subject,
    body: text,
    htmlBody: html,
    name: 'Glass CNC Tools',
  });
}

function generateOtp_() {
  const entropy = [
    Utilities.getUuid(),
    Utilities.getUuid(),
    String(Date.now()),
    String(Math.random()),
  ].join('|');
  const digest = Utilities.computeDigest(
    Utilities.DigestAlgorithm.SHA_256,
    entropy,
    Utilities.Charset.UTF_8
  );
  const firstFourBytes = digest.slice(0, 4);
  let value = 0;
  firstFourBytes.forEach(function(byte) {
    value = (value * 256 + ((byte + 256) % 256)) >>> 0;
  });
  return String(value % 1000000).padStart(6, '0');
}

function saveRecord_(requestId, record) {
  CacheService.getScriptCache().put(
    requestKey_(requestId),
    JSON.stringify(record),
    OTP_TTL_SECONDS + 120
  );
}

function loadRecord_(requestId) {
  const raw = CacheService.getScriptCache().get(requestKey_(requestId));
  if (!raw) return null;
  try {
    return JSON.parse(raw);
  } catch (error) {
    return null;
  }
}

function requestKey_(requestId) {
  return 'otp:' + requestId;
}

function secureHash_(value) {
  const pepper = getPepper_();
  const digest = Utilities.computeDigest(
    Utilities.DigestAlgorithm.SHA_256,
    String(value) + '|' + pepper,
    Utilities.Charset.UTF_8
  );
  return digest
    .map(function(byte) {
      return ((byte + 256) % 256).toString(16).padStart(2, '0');
    })
    .join('');
}

function getPepper_() {
  const properties = PropertiesService.getScriptProperties();
  let pepper = properties.getProperty('OTP_PEPPER');
  if (!pepper) {
    const lock = LockService.getScriptLock();
    lock.waitLock(5000);
    try {
      pepper = properties.getProperty('OTP_PEPPER');
      if (!pepper) {
        pepper = Utilities.getUuid() + Utilities.getUuid() + Utilities.getUuid();
        properties.setProperty('OTP_PEPPER', pepper);
      }
    } finally {
      lock.releaseLock();
    }
  }
  return pepper;
}

function constantEquals_(left, right) {
  left = String(left || '');
  right = String(right || '');
  if (left.length !== right.length) return false;
  let difference = 0;
  for (let i = 0; i < left.length; i += 1) {
    difference |= left.charCodeAt(i) ^ right.charCodeAt(i);
  }
  return difference === 0;
}

function cleanRequestId_(value) {
  value = String(value || '');
  return /^req_[A-Za-z0-9_]{12,120}$/.test(value) ? value : '';
}

function cleanPollToken_(value) {
  value = String(value || '');
  return /^[a-f0-9]{64}$/.test(value) ? value : '';
}

function cleanAttemptId_(value) {
  value = String(value || '');
  if (!value) return '';
  return /^try_[A-Za-z0-9_]{10,120}$/.test(value) ? value : '';
}

function cleanText_(value, maxLength) {
  return String(value || '')
    .replace(/[\u0000-\u001F\u007F]/g, ' ')
    .trim()
    .slice(0, maxLength);
}

function escapeHtml_(value) {
  return String(value || '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

function jsonResponse_(payload) {
  return ContentService.createTextOutput(JSON.stringify(payload))
    .setMimeType(ContentService.MimeType.JSON);
}

function scriptResponse_(storageKey, payload) {
  const keyJson = JSON.stringify(String(storageKey));
  const payloadJson = JSON.stringify(JSON.stringify(payload));
  const script =
    '(function(){try{localStorage.setItem(' + keyJson + ',' + payloadJson + ');}catch(e){}})();';
  return ContentService.createTextOutput(script)
    .setMimeType(ContentService.MimeType.JAVASCRIPT);
}
