// Glass CNC Access Approval - free email edition (no Twilio)
const CONFIG = Object.freeze({
  firebaseApiKey: 'AIzaSyBqCAatF7QEiS3SwtJULyNRVrjxAvF6phI',
  requestLifetimeMs: 30 * 60 * 1000,
  approvedSessionMs: 4 * 60 * 60 * 1000,
  requestPrefix: 'access_request_',
  rateLimitPrefix: 'access_rate_',
});

function doPost(e) {
  try {
    const data = readRequest_(e);
    if (data.action !== 'request') {
      return json_({ok: false, error: 'Unsupported action'});
    }
    return createAccessRequest_(data);
  } catch (error) {
    console.error(error);
    return json_({ok: false, error: 'Request failed'});
  }
}

function doGet(e) {
  try {
    const action = String((e && e.parameter && e.parameter.action) || '');
    if (action === 'decision') return decideRequest_(e.parameter);
    if (action === 'poll') return pollRequest_(e.parameter);
    if (action === 'health') return json_({ok: true, service: 'glass-cnc-access'});
    return htmlPage_('Glass CNC Tools', 'الخدمة تعمل بصورة صحيحة.');
  } catch (error) {
    console.error(error);
    return htmlPage_('خطأ', 'تعذّر تنفيذ الطلب.');
  }
}

function createAccessRequest_(data) {
  const requestId = cleanId_(data.requestId);
  const pollToken = String(data.pollToken || '');
  const requesterName = cleanText_(data.requesterName, 80);
  const tool = cleanText_(data.tool || 'المحوّل والمولّد', 80);
  const idToken = String(data.idToken || '');
  const device = cleanText_(data.device || 'غير معروف', 220);

  if (!requestId || pollToken.length < 32 || !requesterName || !idToken) {
    return json_({ok: false, error: 'Missing or invalid fields'});
  }

  const identity = verifyFirebaseToken_(idToken);
  if (!identity || !identity.localId) {
    return json_({ok: false, error: 'Authentication failed'});
  }

  const lock = LockService.getScriptLock();
  lock.waitLock(5000);
  try {
    cleanupExpiredRequests_();
    enforceRateLimit_(identity.localId);

    const now = Date.now();
    const approveToken = randomToken_();
    const rejectToken = randomToken_();
    const record = {
      id: requestId,
      uid: identity.localId,
      requesterName: requesterName,
      requesterEmail: cleanText_(identity.email || '', 180),
      tool: tool,
      device: device,
      status: 'pending',
      createdAt: now,
      expiresAt: now + CONFIG.requestLifetimeMs,
      approvedUntil: null,
      decidedAt: null,
      pollTokenHash: sha256_(pollToken),
      approveTokenHash: sha256_(approveToken),
      rejectTokenHash: sha256_(rejectToken),
    };

    PropertiesService.getScriptProperties().setProperty(
      CONFIG.requestPrefix + requestId,
      JSON.stringify(record)
    );

    try {
      sendApprovalMessage_(record, approveToken, rejectToken);
    } catch (error) {
      record.status = 'error';
      PropertiesService.getScriptProperties().setProperty(
        CONFIG.requestPrefix + requestId,
        JSON.stringify(record)
      );
      throw error;
    }

    return json_({ok: true, requestId: requestId, expiresAt: record.expiresAt});
  } finally {
    lock.releaseLock();
  }
}

function pollRequest_(params) {
  const requestId = cleanId_(params.id);
  const pollToken = String(params.token || '');
  const callback = String(params.callback || '');
  const storageKey = String(params.storageKey || '');
  let payload;

  if (!requestId || pollToken.length < 32) {
    payload = {ok: false, status: 'invalid'};
  } else {
    const record = getRequest_(requestId);
    if (!record || !constantTimeEquals_(record.pollTokenHash, sha256_(pollToken))) {
      payload = {ok: false, status: 'invalid'};
    } else if (record.status === 'pending' && Date.now() > record.expiresAt) {
      record.status = 'expired';
      saveRequest_(record);
      payload = publicStatus_(record);
    } else {
      payload = publicStatus_(record);
    }
  }

  if (/^[A-Za-z_$][A-Za-z0-9_$\.]{0,80}$/.test(callback)) {
    return ContentService
      .createTextOutput(callback + '(' + JSON.stringify(payload) + ');')
      .setMimeType(ContentService.MimeType.JAVASCRIPT);
  }

  if (/^[A-Za-z0-9_\-]{1,100}$/.test(storageKey)) {
    const js = 'localStorage.setItem(' + JSON.stringify(storageKey) + ',' +
      JSON.stringify(JSON.stringify(payload)) + ');';
    return ContentService.createTextOutput(js)
      .setMimeType(ContentService.MimeType.JAVASCRIPT);
  }

  return json_(payload);
}

function decideRequest_(params) {
  const requestId = cleanId_(params.id);
  const decision = String(params.value || '');
  const token = String(params.token || '');
  if (!requestId || !['approved', 'rejected'].includes(decision) || token.length < 32) {
    return htmlPage_('رابط غير صالح', 'رابط الموافقة غير صحيح.');
  }

  const lock = LockService.getScriptLock();
  lock.waitLock(5000);
  try {
    const record = getRequest_(requestId);
    if (!record) return htmlPage_('طلب غير موجود', 'هذا الطلب غير موجود أو تم حذفه.');
    if (record.status !== 'pending') {
      return htmlPage_('تم اتخاذ القرار', statusArabic_(record.status));
    }
    if (Date.now() > record.expiresAt) {
      record.status = 'expired';
      saveRequest_(record);
      return htmlPage_('انتهى الطلب', 'انتهت مهلة الموافقة. اطلب من المستخدم المحاولة مرة أخرى.');
    }

    const expectedHash = decision === 'approved'
      ? record.approveTokenHash
      : record.rejectTokenHash;
    if (!constantTimeEquals_(expectedHash, sha256_(token))) {
      return htmlPage_('رابط غير صالح', 'رمز الموافقة غير صحيح.');
    }

    record.status = decision;
    record.decidedAt = Date.now();
    record.approvedUntil = decision === 'approved'
      ? record.decidedAt + CONFIG.approvedSessionMs
      : null;
    saveRequest_(record);

    return decision === 'approved'
      ? htmlPage_('تم قبول الدخول', 'تم السماح لـ ' + record.requesterName + ' بالدخول لمدة 4 ساعات.')
      : htmlPage_('تم رفض الدخول', 'تم منع ' + record.requesterName + ' من الدخول.');
  } finally {
    lock.releaseLock();
  }
}

function sendApprovalMessage_(record, approveToken, rejectToken) {
  const props = PropertiesService.getScriptProperties();
  const ownerEmail = String(
    props.getProperty('OWNER_EMAIL') ||
    Session.getEffectiveUser().getEmail() ||
    'rashedhathalmic@gmail.com'
  ).trim();
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(ownerEmail)) {
    throw new Error('OWNER_EMAIL is invalid');
  }
  if (MailApp.getRemainingDailyQuota() < 1) {
    throw new Error('Daily email quota is exhausted');
  }

  const baseUrl = ScriptApp.getService().getUrl();
  if (!baseUrl) throw new Error('Deploy the script as a web app first');

  const approveUrl = baseUrl + '?action=decision&id=' + encodeURIComponent(record.id) +
    '&value=approved&token=' + encodeURIComponent(approveToken);
  const rejectUrl = baseUrl + '?action=decision&id=' + encodeURIComponent(record.id) +
    '&value=rejected&token=' + encodeURIComponent(rejectToken);
  const time = Utilities.formatDate(new Date(record.createdAt), 'Asia/Riyadh', 'yyyy-MM-dd HH:mm:ss');
  const requesterEmail = String(record.requesterEmail || 'غير متوفر');
  const plainBody = [
    'طلب دخول جديد إلى Glass CNC Tools',
    '',
    'الاسم: ' + record.requesterName,
    'البريد: ' + requesterEmail,
    'الأداة: ' + record.tool,
    'الوقت: ' + time + ' (توقيت السعودية)',
    'الجهاز: ' + record.device,
    '',
    'قبول الدخول:',
    approveUrl,
    '',
    'رفض الدخول:',
    rejectUrl,
    '',
    'تنتهي صلاحية الطلب بعد 30 دقيقة.'
  ].join('\n');

  const safeName = escapeHtml_(record.requesterName);
  const safeEmail = escapeHtml_(requesterEmail);
  const safeTool = escapeHtml_(record.tool);
  const safeDevice = escapeHtml_(record.device);
  const safeTime = escapeHtml_(time);
  const htmlBody =
    '<div dir="rtl" style="font-family:Arial,sans-serif;background:#f4f7fb;padding:24px">' +
      '<div style="max-width:620px;margin:auto;background:#fff;border:1px solid #e2e8f0;border-radius:16px;padding:28px">' +
        '<h2 style="margin:0 0 20px;color:#17324d">طلب دخول جديد إلى Glass CNC Tools</h2>' +
        '<table style="width:100%;border-collapse:collapse;font-size:16px;line-height:1.8">' +
          '<tr><td style="font-weight:bold;width:110px">الاسم</td><td>' + safeName + '</td></tr>' +
          '<tr><td style="font-weight:bold">البريد</td><td>' + safeEmail + '</td></tr>' +
          '<tr><td style="font-weight:bold">الأداة</td><td>' + safeTool + '</td></tr>' +
          '<tr><td style="font-weight:bold">الوقت</td><td>' + safeTime + ' (توقيت السعودية)</td></tr>' +
          '<tr><td style="font-weight:bold">الجهاز</td><td>' + safeDevice + '</td></tr>' +
        '</table>' +
        '<div style="margin-top:26px;text-align:center">' +
          '<a href="' + approveUrl + '" style="display:inline-block;background:#16803c;color:#fff;text-decoration:none;padding:13px 28px;border-radius:10px;font-weight:bold;margin:6px">قبول الدخول</a>' +
          '<a href="' + rejectUrl + '" style="display:inline-block;background:#c62828;color:#fff;text-decoration:none;padding:13px 28px;border-radius:10px;font-weight:bold;margin:6px">رفض الدخول</a>' +
        '</div>' +
        '<p style="margin:24px 0 0;color:#64748b;font-size:14px;text-align:center">تنتهي صلاحية الطلب بعد 30 دقيقة، ولا يعمل الرابط إلا مرة واحدة.</p>' +
      '</div>' +
    '</div>';

  MailApp.sendEmail({
    to: ownerEmail,
    subject: 'طلب دخول جديد: ' + record.requesterName + ' - ' + record.tool,
    body: plainBody,
    htmlBody: htmlBody,
    name: 'Glass CNC Access Approval',
  });
}

function verifyFirebaseToken_(idToken) {
  const response = UrlFetchApp.fetch(
    'https://identitytoolkit.googleapis.com/v1/accounts:lookup?key=' +
      encodeURIComponent(CONFIG.firebaseApiKey),
    {
      method: 'post',
      contentType: 'application/json',
      payload: JSON.stringify({idToken: idToken}),
      muteHttpExceptions: true,
    }
  );
  if (response.getResponseCode() !== 200) return null;
  const parsed = JSON.parse(response.getContentText());
  return parsed.users && parsed.users.length ? parsed.users[0] : null;
}

function testEmail() {
  const fake = {
    id: 'test-' + Utilities.getUuid(),
    requesterName: 'اختبار النظام',
    requesterEmail: Session.getEffectiveUser().getEmail() || 'غير متوفر',
    tool: 'المحوّل والمولّد',
    device: 'Google Apps Script',
    createdAt: Date.now(),
  };
  sendApprovalMessage_(fake, randomToken_(), randomToken_());
}

function readRequest_(e) {
  if (!e) return {};
  if (e.postData && e.postData.contents) {
    const type = String(e.postData.type || '').toLowerCase();
    if (type.indexOf('application/json') >= 0 || e.postData.contents.trim().charAt(0) === '{') {
      return JSON.parse(e.postData.contents);
    }
  }
  return e.parameter || {};
}

function enforceRateLimit_(uid) {
  const props = PropertiesService.getScriptProperties();
  const key = CONFIG.rateLimitPrefix + sha256_(uid).slice(0, 24);
  const last = Number(props.getProperty(key) || 0);
  const now = Date.now();
  if (now - last < 30000) throw new Error('Please wait before requesting again');
  props.setProperty(key, String(now));
}

function cleanupExpiredRequests_() {
  const props = PropertiesService.getScriptProperties();
  const all = props.getProperties();
  const cutoff = Date.now() - 24 * 60 * 60 * 1000;
  Object.keys(all).forEach(function(key) {
    if (key.indexOf(CONFIG.requestPrefix) !== 0) return;
    try {
      const record = JSON.parse(all[key]);
      if (Number(record.expiresAt || 0) < cutoff) props.deleteProperty(key);
    } catch (_) {
      props.deleteProperty(key);
    }
  });
}

function getRequest_(id) {
  const raw = PropertiesService.getScriptProperties()
    .getProperty(CONFIG.requestPrefix + id);
  return raw ? JSON.parse(raw) : null;
}

function saveRequest_(record) {
  PropertiesService.getScriptProperties().setProperty(
    CONFIG.requestPrefix + record.id,
    JSON.stringify(record)
  );
}

function publicStatus_(record) {
  return {
    ok: true,
    status: record.status,
    expiresAt: record.expiresAt,
    approvedUntil: record.approvedUntil,
  };
}

function randomToken_() {
  return sha256_(Utilities.getUuid() + '|' + Utilities.getUuid() + '|' + Date.now());
}

function sha256_(value) {
  const bytes = Utilities.computeDigest(
    Utilities.DigestAlgorithm.SHA_256,
    String(value),
    Utilities.Charset.UTF_8
  );
  return bytes.map(function(b) {
    const normalized = b < 0 ? b + 256 : b;
    return ('0' + normalized.toString(16)).slice(-2);
  }).join('');
}

function constantTimeEquals_(a, b) {
  a = String(a || '');
  b = String(b || '');
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

function cleanId_(value) {
  value = String(value || '');
  return /^[A-Za-z0-9_-]{12,100}$/.test(value) ? value : '';
}

function cleanText_(value, maxLength) {
  return String(value || '').replace(/[\u0000-\u001F\u007F]/g, ' ').trim().slice(0, maxLength);
}

function statusArabic_(status) {
  if (status === 'approved') return 'تم قبول هذا الطلب مسبقًا.';
  if (status === 'rejected') return 'تم رفض هذا الطلب مسبقًا.';
  if (status === 'expired') return 'انتهت صلاحية هذا الطلب.';
  if (status === 'error') return 'تعذر إرسال إشعار هذا الطلب.';
  return 'حالة الطلب: ' + status;
}

function json_(value) {
  return ContentService.createTextOutput(JSON.stringify(value))
    .setMimeType(ContentService.MimeType.JSON);
}

function htmlPage_(title, message) {
  const safeTitle = escapeHtml_(title);
  const safeMessage = escapeHtml_(message);
  return HtmlService.createHtmlOutput(
    '<!doctype html><html lang="ar" dir="rtl"><head><meta charset="utf-8">' +
    '<meta name="viewport" content="width=device-width,initial-scale=1">' +
    '<title>' + safeTitle + '</title><style>' +
    'body{font-family:Arial,sans-serif;background:#f4f7fb;margin:0;display:grid;place-items:center;min-height:100vh}' +
    '.card{background:#fff;padding:32px;border-radius:18px;box-shadow:0 12px 40px #1d35571f;max-width:520px;text-align:center}' +
    'h1{color:#17324d;margin:0 0 16px}p{font-size:18px;line-height:1.7;color:#46576a}' +
    '</style></head><body><main class="card"><h1>' + safeTitle + '</h1><p>' +
    safeMessage + '</p></main></body></html>'
  ).setXFrameOptionsMode(HtmlService.XFrameOptionsMode.ALLOWALL);
}

function escapeHtml_(value) {
  return String(value).replace(/[&<>"']/g, function(char) {
    return {'&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'}[char];
  });
}
