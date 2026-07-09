require('dotenv').config();
const httpntlm = require('httpntlm');

const pass = process.env.EMAIL_PASS;

const soap = [
  '<?xml version="1.0" encoding="utf-8"?>',
  '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"',
  '  xmlns:t="http://schemas.microsoft.com/exchange/services/2006/types"',
  '  xmlns:m="http://schemas.microsoft.com/exchange/services/2006/messages">',
  '  <soap:Body>',
  '    <m:FindItem Traversal="Shallow">',
  '      <m:ItemShape><t:BaseShape>IdOnly</t:BaseShape></m:ItemShape>',
  '      <m:CalendarView StartDate="2026-07-01T00:00:00Z" EndDate="2026-07-31T23:59:59Z" MaxEntriesReturned="3"/>',
  '      <m:ParentFolderIds>',
  '        <t:DistinguishedFolderId Id="calendar"/>',
  '      </m:ParentFolderIds>',
  '    </m:FindItem>',
  '  </soap:Body>',
  '</soap:Envelope>'
].join('\n');

function tryAuth(label, opts) {
  return new Promise(resolve => {
    httpntlm.post({
      ...opts,
      body: soap,
      headers: { 'Content-Type': 'text/xml; charset=utf-8' },
    }, function(err, res) {
      const status = err ? 'ERR:' + err.message : 'HTTP ' + res.statusCode;
      const body = (!err && res.body) ? res.body.toString().slice(0, 200) : '';
      console.log(label, '->', status, body ? '| ' + body.replace(/\s+/g,' ').slice(0,100) : '');
      resolve();
    });
  });
}

(async () => {
  // Try 1: DOMAIN\user with short domain
  await tryAuth('NTLM triasmail\\budi.purwanto', {
    url: 'https://mail.trst.co.id/EWS/Exchange.asmx',
    username: 'budi.purwanto', password: pass, domain: 'triasmail',
  });
  // Try 2: email address as username (no domain)
  await tryAuth('NTLM email address', {
    url: 'https://mail.trst.co.id/EWS/Exchange.asmx',
    username: 'budi.purwanto@trst.co.id', password: pass, domain: '',
  });
  // Try 3: FQDN domain
  await tryAuth('NTLM triasmail.co.id domain', {
    url: 'https://mail.trst.co.id/EWS/Exchange.asmx',
    username: 'budi.purwanto', password: pass, domain: 'triasmail.co.id',
  });
  // Try 4: different URL path casing / EWS autodiscover
  await tryAuth('EWS lowercase path', {
    url: 'https://mail.trst.co.id/ews/exchange.asmx',
    username: 'budi.purwanto', password: pass, domain: 'triasmail',
  });
})();
