const CLASSES = [
  { id: 1, key: 'scout', label: 'Scout', icon: 'scout.png' },
  { id: 2, key: 'sniper', label: 'Sniper', icon: 'sniper.png' },
  { id: 3, key: 'soldier', label: 'Soldier', icon: 'soldier.png' },
  { id: 4, key: 'demoman', label: 'Demoman', icon: 'demoman.png' },
  { id: 5, key: 'medic', label: 'Medic', icon: 'medic.png' },
  { id: 6, key: 'heavy', label: 'Heavy', icon: 'heavy.png' },
  { id: 7, key: 'pyro', label: 'Pyro', icon: 'pyro.png' },
  { id: 8, key: 'spy', label: 'Spy', icon: 'spy.png' },
  { id: 9, key: 'engineer', label: 'Engineer', icon: 'engineer.png' }
];

const state = {
  data: {}, // { classKey: [ { name, effects: [segments], icon } ] }
  activeClass: 'scout',
  filter: ''
};

const classClickSound = new Audio('sound/tf2-button-click.mp3');
classClickSound.preload = 'auto';

function $(sel, root = document) { return root.querySelector(sel); }
function $all(sel, root = document) { return Array.from(root.querySelectorAll(sel)); }

// Manual icon mapping per entry; stop guessing/slugging
const ICONS = {
  // Scout
  'Back Scatter': "100px-item_icon_back_scatter.png",
  "Baby Face's": "100px-item_icon_baby_face's_blaster.png",
  'The Shortstop': '100px-item_icon_shortstop.png',
  'Flying Guillotine': '100px-item_icon_flying_guillotine.png',
  'Crit-a-Cola': '100px-item_icon_crit-a-cola.png',
  'The Sandman': '100px-item_icon_sandman.png',
  'Candy Cane': '100px-item_icon_candy_cane.png',
  "Fan-o-War": "100px-Item_icon_Fan_O'War.png",

  // Soldier
  'Air Strike': '100px-item_icon_air_strike.png',
  'Liberty Launcher': '100px-item_icon_liberty_launcher.png',
  'Righteous Bison': '100px-item_icon_righteous_bison.png',
  'Base Jumper': '100px-item_icon_b.a.s.e._jumper.png',
  'Equalizer': '100px-item_icon_equalizer.png',

  // Pyro
  "Dragon's Fury": "100px-item_icon_dragon's_fury.png",
  'Degreaser': '100px-item_icon_degreaser.png',
  'Detonator': '100px-item_icon_detonator.png',
  'Axtinguisher': 'axtinguisher.png',
  'Volcano Fragment': '100px-item_icon_sharpened_volcano_fragment.png',

  // Demoman
  'Booties': 'booties.png',
  // Base Jumper handled above
  'Sticky Jumper': 'sticky_jumper.png',
  'Scottish Resistance': 'scottish_resistance.png',
  'Shields': 'shields.png',
  'Caber': '100px-item_icon_ullapool_caber.png',
  'Scottish Handshake': 'scottish_handshake.png',

  // Heavy
  'Huo-Long Heater': '100px-item_icon_huo-long_heater.png',
  'Natascha': '100px-item_icon_natascha.png',
  'Shotguns': '100px-item_icon_panic_attack.png',
  'Gloves of Running': '100px-item_gloves_of_running.png',
  'Eviction Notice': '100px-Item_icon_Eviction_Notice.png',
  "Warrior's Spirit": "100px-item_icon_warrior's_spirit.png",

  // Engineer
  'Pomson': '100px-item_icon_pomson_6000.png',
  'The Wrangler': '100px-item_icon_wrangler.png',
  'The Short Circuit': '100px-item_icon_short_circuit.png',
  'Southern Hospitality': '100px-item_icon_southern_hospitality.png',
  'Sentry Guns': 'sentry.png',
  'Amplifier': 'amplifier.png',

  // Medic
  'Syringe Guns': '100px-item_icon_syringe_gun.png',
  'The Vita-Saw': '100px-item_icon_vita-saw.png',
  'The Vaccinator': '100px-item_icon_vaccinator.png',

  // Sniper
  'The Huntsman': '100px-item_icon_huntsman.png',
  'The Classic': '100px-item_icon_classic.png',
  'The Cozy Camper': '100px-Item_cozy_camper.png',
  "The Cleaner's Carbine": "100px-item_icon_cleaner's_carbine.png",
  "The Tribalman's Shiv": "100px-Item_icon_Tribalman's_Shiv.png",

  // Spy
  'The Ambassador': '100px-item_icon_ambassador.png',
  'The Enforcer': '100px-item_icon_enforcer.png',
  'The Big Earner': 'big_earner.png',
  'Your Eternal Reward': '100px-item_icon_your_eternal_reward.png'
};

const DATA_URL = 'data/changes.json';

function sanitizeItem(item) {
  const name = item && typeof item.name === 'string' ? item.name : '';
  const effects = Array.isArray(item && item.effects)
    ? item.effects.map(effect => String(effect ?? '')).map(e => e.trim())
    : [];
  return { name, effects };
}

function normalizeData(raw) {
  const out = {};
  if (raw && typeof raw === 'object') {
    Object.entries(raw).forEach(([classKey, items]) => {
      if (!Array.isArray(items)) return;
      out[classKey] = items.map(sanitizeItem);
    });
  }
  return out;
}

function classifySegment(seg) {
  const s = seg.trim();
  if (!s) return { text: s, cls: 'neutral' };
  const low = s.toLowerCase();
  const upsideCues = ['more accurate', '+15 hp', 'allies', 'more health', 'ber on hit', '+5', '+20% dam', 'no active', 'lights up', 'penetrat', '+20 health', 'bonus', '+50% reload', '15 metal', '+15% reload', '+10%', 'charge', 'healing', 'boost kept', 'no damage penalty', '+100%', 'no health drain', 'no active damage penalty', 'penalty reduced', 'less bullet spread', '102', '0% cloak', 'airblast jump', 'mini-crits burning', 'crits burning', 'no mark', 'damage vulnerability reduced', 'wall climbing', 'no aim flinch', 'on kill', 'instead of', 'deploy', 'ranged sources', 'hitbox', 'ignores', 'ignites', 'stuns', 'even without', 'max stickies', 'arm time', 'provide', 'deals 1', 'market', 'holster', 'retain'];
  const downsideCues = ['violent', 'does not slow', '-20% base', '-95%', 'all resistances', '+20% damage taken', '-20', '75% less', 'marks for', 'non-burning', '66%', 'No ammo', 'range', 'no disguise'];
  const isDown = downsideCues.some(c => low.includes(c)) && !low.includes('+');
  const isUp = !isDown && upsideCues.some(c => low.includes(c));
  const cls = isDown ? 'downside' : (isUp ? 'upside' : 'neutral');
  return { text: s, cls };
}

function renderClasses() {
  const bar = $('#class-bar');
  bar.innerHTML = '';
  CLASSES.forEach(c => {
    const btn = document.createElement('button');
    btn.className = 'class-btn' + (state.activeClass === c.key ? ' active' : '');
    btn.dataset.class = c.key;
    btn.innerHTML = `<img class="class-icon" src="icons/${c.icon}" alt="${c.label}"><span class="class-label">${c.label}</span>`;
    btn.addEventListener('click', () => {
      state.activeClass = c.key;
      if (classClickSound) {
        try {
          classClickSound.currentTime = 0;
          classClickSound.play().catch(() => {});
        } catch (err) {
          console.warn('[MapsInfo] Failed to play class sound', err);
        }
      }
      update();
    });
    bar.appendChild(btn);
  });
}

function renderBackpack() {
  const wrap = document.getElementById('button-container');
  let list = [];
  const filterActive = !!state.filter;
  if (filterActive) {
    // Search across all classes when a filter is present
    Object.entries(state.data).forEach(([classKey, items]) => {
      items.forEach((e, idx) => {
        const hay = (e.name + ' ' + e.effects.join(' ')).toLowerCase();
        if (!state.filter || hay.includes(state.filter)) {
          list.push({ classKey, index: idx, item: e });
        }
      });
    });
  } else {
    // Default to active class when no filter
    list = (state.data[state.activeClass] || []).map((e, idx) => ({ classKey: state.activeClass, index: idx, item: e }));
  }
  wrap.innerHTML = '';
  if (list.length === 0) {
    const empty = document.createElement('div');
    empty.className = 'empty';
    empty.textContent = 'No changes for this class match your filter.';
    wrap.appendChild(empty);
    return;
  }
  list.forEach(entry => {
    const { classKey, index, item } = entry;
    const a = document.createElement('a');
    a.href = '#';
    a.className = 'on';
    const syncTitle = () => { a.title = `${item.name}: ${item.effects.join('; ')}`; };
    a.addEventListener('click', evt => evt.preventDefault());
    const img = document.createElement('img');
    img.className = 'btn-icon';
    img.alt = item.name;
    const span = document.createElement('span');
    span.className = 'btn-label';
    span.textContent = item.name;
    // Effects block (render visible changes on the tile)
    const eff = document.createElement('div');
    eff.className = 'effects';
    item.effects.forEach((effectText, effectIdx) => {
      const seg = classifySegment(effectText);
      const s = document.createElement('span');
      s.className = 'seg ' + seg.cls;
      s.textContent = seg.text;
      eff.appendChild(s);
    });
    a.appendChild(img);
    a.appendChild(span);
    a.appendChild(eff);
    syncTitle();
    setWeaponIcon(img, item.name, classKey);
    wrap.appendChild(a);
  });
}

function setWeaponIcon(imgEl, weaponName, preferClassKey) {
  const direct = ICONS[weaponName];
  if (direct) {
    imgEl.src = `icons/${direct}`;
    imgEl.style.display = '';
    return;
  }
  // Minimal fallback: try without leading "The " if a mapping exists
  const noThe = weaponName.replace(/^The\s+/i, '');
  if (ICONS[noThe]) {
    imgEl.src = `icons/${ICONS[noThe]}`;
    imgEl.style.display = '';
    return;
  }
  // Last resort: use class icon to avoid broken images
  const cls = CLASSES.find(c => c.key === preferClassKey) || CLASSES.find(c => c.key === state.activeClass) || CLASSES[0];
  imgEl.src = `icons/${cls.icon}`;
  imgEl.style.display = '';
}

async function loadData() {
  try {
    const resp = await fetch(`${DATA_URL}?v=${Date.now()}`);
    if (!resp.ok) throw new Error('HTTP ' + resp.status);
    const payload = await resp.json();
    if (!payload || typeof payload !== 'object') throw new Error('Invalid payload');
    state.data = normalizeData(payload);
  } catch (err) {
    console.warn('Failed to load data file; using defaults', err);
    state.data = {};
  }
}

function update() {
  renderClasses();
  renderBackpack();
}

async function main() {
  const search = $('#search');
  search.addEventListener('input', () => {
    state.filter = (search.value || '').trim().toLowerCase();
    renderBackpack();
  });
  await loadData();
  renderClasses();
  renderBackpack();
}

main();
