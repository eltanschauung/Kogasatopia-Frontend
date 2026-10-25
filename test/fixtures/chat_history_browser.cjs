const assert = require('node:assert/strict');
const {test} = require('node:test');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

function hook() {
  let hooks;
  const window = {Phoenix: {Socket: class {}}, LiveView: {LiveSocket: class {
    constructor(_url, _socket, opts) { hooks = opts.hooks; }
    connect() {}
  }}};
  vm.runInNewContext(fs.readFileSync(path.join(__dirname, '../../priv/static/assets/js/app.js'), 'utf8'), {
    window, document: {querySelector() { return null; }}
  });
  let finishes = 0;
  const instance = {...hooks.ChatViewport, el: {dataset: {historyMode: '1'}},
    finishLiveBottom() { finishes++; }};
  return {instance, finishes: () => finishes};
}

test('history bottom requests a fresh tail and waits for acceptance', () => {
  const h = hook(); let callback;
  h.instance.pushEvent = (event, _params, cb) => { assert.equal(event, 'load_latest'); callback = cb; };
  h.instance.showLiveBottom(); assert.equal(h.finishes(), 0);
  callback({live: false}); assert.equal(h.finishes(), 0);
  callback({live: true}); assert.equal(h.finishes(), 1);
});
test('live bottom needs no extra database request', () => {
  const h = hook(); h.instance.el.dataset.historyMode = '0';
  h.instance.pushEvent = () => { throw new Error('unnecessary request'); };
  h.instance.showLiveBottom(); assert.equal(h.finishes(), 1);
});
