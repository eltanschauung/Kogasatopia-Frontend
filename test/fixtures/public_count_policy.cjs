const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

(async () => {
  const calls = [];
  const label = { getAttribute: () => null };
  let hooks;
  const context = {
    WTOnlineCountCache: { write() {} },
    window: {
      Phoenix: { Socket: function() {} },
      LiveView: { LiveSocket: function(_path, _socket, opts) { hooks = opts.hooks; this.connect = () => {}; } },
      WTOnlineCountCache: { write() {} },
    },
    document: { querySelector: () => null, getElementById: () => label },
    fetch: async (url, opts) => {
      calls.push([url, opts]);
      return { ok: true, json: async () => ({ player_count: 4, visible_max: 32 }) };
    },
  };
  vm.createContext(context);
  vm.runInContext(fs.readFileSync('priv/static/assets/js/app/nav_status.js', 'utf8'), context);
  await context.window.WTNavStatus.updateOnline(label);
  assert.equal(calls[0][0], '/stats/online_summary.php');
  assert.equal(calls[0][1].cache, 'default');
  assert.equal(label.textContent, '4 / 32');
  vm.runInContext(fs.readFileSync('priv/static/assets/js/app.js', 'utf8'), context);
  await hooks.ChatViewport.updateNavCount.call({ navCountEl: label, onlineSummaryEndpoint: '/stats/online_summary.php' });
  assert.equal(calls[1][0], '/stats/online_summary.php');
  assert.equal(calls[1][1].cache, 'default');
  assert.equal(label.textContent, '4 / 32');
  // Guard policies that must remain fresh and unchanged.
  const stats = fs.readFileSync('lib/kogasa_frontend_web/controllers/stats_html/index.html.heex', 'utf8');
  assert.match(stats, /fetch\('\/stats\/online\.php\?identity=stats', \{ cache: 'no-store' \}/);
  assert.match(stats, /current_log_fragment\.php\?identity=stats&t=' \+ Date\.now\(\), \{ cache: 'no-store' \}/);
  assert.match(fs.readFileSync('priv/static/assets/js/app/chat_age_label.js', 'utf8'), /cache: "no-store"/);
  assert.match(fs.readFileSync('lib/kogasa_frontend_web/controllers/online_html/index.html.heex', 'utf8'), /fetch\(onlineEndpoint, \{ cache: 'no-store' \}/);
  console.log('public count policy passed: both mocked fetch paths and unchanged detail/chat/current-log policies');
})().catch(error => { console.error(error); process.exitCode = 1; });
