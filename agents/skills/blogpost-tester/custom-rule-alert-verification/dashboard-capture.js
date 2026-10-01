// Usage: node ui.js <mode> <outprefix>
//   mode=rules  : screenshot Server management > Rules, open the Add new rules file editor, list button labels
//   mode=events : Threat Hunting > Events; env Q=<DQL query>, TFROM/TTO=<rison time, e.g. 'now-4h' or '2026-09-29T12:48:00.000Z'>
//   mode=nav    : dump the side-nav labels (verify a doc's menu path)
// Setup: npm install puppeteer-core (uses the local Chrome, no Chromium download)
const puppeteer = require('puppeteer-core');
const fs = require('fs');
const [mode, out] = process.argv.slice(2);
const HOST = process.env.WAZUH_DASH; // e.g. https://<server-public-ip>
const creds = fs.readFileSync(process.env.WAZUH_CREDS, 'utf8'); // wazuh-passwords.txt from wazuh-install-files.tar
const pw = creds.match(/indexer_username: 'admin'\s+indexer_password: '([^']+)'/)[1];
const sleep = ms => new Promise(r => setTimeout(r, ms));

(async () => {
  const browser = await puppeteer.launch({
    executablePath: 'C:/Program Files/Google/Chrome/Application/chrome.exe',
    headless: 'new', ignoreHTTPSErrors: true, acceptInsecureCerts: true,
    userDataDir: __dirname + '/profile-' + Date.now(),
    args: ['--no-sandbox', '--disable-gpu', '--ignore-certificate-errors', '--window-size=1600,1000'],
    defaultViewport: { width: 1600, height: 1000 },
  });
  const page = await browser.newPage();
  await page.goto(HOST + '/app/login', { waitUntil: 'networkidle2', timeout: 90000 });
  await page.waitForSelector('input[type="password"]', { timeout: 60000 });
  await page.type('input[type="text"]', 'admin');
  await page.type('input[type="password"]', pw);
  await Promise.all([page.click('button[type="submit"]'), page.waitForNavigation({ timeout: 90000 }).catch(() => {})]);
  await sleep(6000);
  const texts = async () => page.evaluate(() => Array.from(document.querySelectorAll('button, a, [role="tab"]'))
    .map(e => (e.innerText || '').trim()).filter(t => t && t.length < 60));

  if (mode === 'rules') {
    await page.goto(HOST + '/app/rules', { waitUntil: 'networkidle2', timeout: 90000 });
    await sleep(8000);
    await page.screenshot({ path: out + '-rules.png' });
    console.log('RULES PAGE URL', page.url());
    console.log('BUTTONS', JSON.stringify([...new Set(await texts())]));
    // open the rules-file editor (verifies the Save button label)
    const html = await page.content();
    console.log('has Add new rules file:', /Add new rules file/.test(html), '| Custom rules toggle:', /Custom rules/.test(html));
    // navigate to custom rules file list by clicking "Manage rules files" if present
    let clicked = false;
    for (let i = 0; i < 10 && !clicked; i++) {
      await sleep(2000);
      clicked = await page.evaluate(() => {
        const b = Array.from(document.querySelectorAll('button')).find(x => /Add new rules file/.test(x.innerText));
        if (b) { b.click(); return true; } return false;
      });
    }
    await sleep(5000);
    console.log('clicked add new:', clicked);
    await page.screenshot({ path: out + '-addnew.png' });
    console.log('EDITOR BUTTONS', JSON.stringify([...new Set(await texts())]));
  } else if (mode === 'events') {
    const q = encodeURIComponent("(query:(language:kuery,query:'rule.groups:custom'))");
    await page.goto(HOST + `/app/threat-hunting#/overview/?tab=general&tabView=events&_g=(time:(from:${process.env.TFROM||'now-4h'},to:${process.env.TTO||'now'}))&_q=${q}`, { waitUntil: 'networkidle2', timeout: 90000 });
    await sleep(12000);
    // the search bar can take a while on the first load after login; wait for it instead of one lookup
    const box = await page.waitForSelector('[data-test-subj="queryInput"]', { timeout: 60000 }).catch(() => null);
    if (box) { await box.click({ clickCount: 3 }); await page.keyboard.type(process.env.Q || 'rule.groups:custom'); await page.keyboard.press('Enter'); }
    console.log('typed query:', !!box);
    await sleep(10000);
    console.log('URL', page.url());
    const menu = await page.evaluate(() => document.title + ' | ' + Array.from(document.querySelectorAll('h1,h2,[data-test-subj*="breadcrumb"]')).map(e => e.innerText).join(' / '));
    console.log('HEAD', menu);
    const hits = await page.evaluate(() => (document.body.innerText.match(/([\d,]+)\s+hits?/) || [])[0]);
    console.log('HITS', hits);
    await page.addStyleTag({ content: '.euiGlobalToastList{display:none!important}' });
    await sleep(1000);
    await page.screenshot({ path: out + '-events.png', fullPage: false });
  } else if (mode === 'nav') {
    await page.goto(HOST + '/app/wz-home', { waitUntil: 'networkidle2', timeout: 90000 });
    await sleep(6000);
    // open side nav
    await page.evaluate(() => { const b = document.querySelector('[data-test-subj="toggleNavButton"]'); if (b) b.click(); });
    await sleep(3000);
    const nav = await page.evaluate(() => Array.from(document.querySelectorAll('nav a, nav button, .euiCollapsibleNavGroup *[class*="title"]')).map(e => e.innerText.trim()).filter(Boolean));
    console.log('NAV', JSON.stringify([...new Set(nav)]));
    await page.screenshot({ path: out + '-nav.png' });
  }
  await browser.close();
})().catch(e => { console.error('ERR', e.message); process.exit(1); });
