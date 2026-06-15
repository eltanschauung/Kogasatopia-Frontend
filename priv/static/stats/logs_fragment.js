(() => {
  const container = document.getElementById('logs-container');
  const emptyState = document.getElementById('logs-empty');
  const toggleOld = document.getElementById('logs-toggle-old');
  const refreshBtn = document.getElementById('logs-refresh');
  if (!container) return;

  let showOld = true;
  const fragmentUrl = container.dataset.fragment || 'logs_fragment.php';
  const scope = container.dataset.scope || 'regular';

  const applyFilters = () => {
    const entries = container.querySelectorAll('.log-entry');
    let visible = 0;
    entries.forEach(entry => {
      let hide = false;
      if (!showOld) {
        const startedAt = Number(entry.dataset.startedAt || 0);
        if (startedAt > 0) {
          const now = Math.floor(Date.now() / 1000);
          if ((now - startedAt) > 86400 * 2) hide = true;
        }
      }
      entry.style.display = hide ? 'none' : '';
      if (!hide) visible++;
    });
    if (emptyState) {
      emptyState.style.display = visible === 0 ? '' : 'none';
    }
  };

  const fetchFragment = () => {
    const url = `${fragmentUrl}?limit=60&scope=${encodeURIComponent(scope)}&t=${Date.now()}`;
    fetch(url)
      .then(resp => {
        if (!resp.ok) throw new Error('HTTP ' + resp.status);
        return resp.text();
      })
      .then(html => {
        container.innerHTML = html;
        applyFilters();
      })
      .catch(err => {
        console.error('[WhaleTracker] Failed to load logs fragment', err);
        if (emptyState) {
          emptyState.textContent = 'Failed to load logs.';
          emptyState.style.display = '';
        }
      });
  };

  if (refreshBtn) refreshBtn.addEventListener('click', () => fetchFragment());
  if (toggleOld) toggleOld.addEventListener('click', () => {
    showOld = !showOld;
    toggleOld.textContent = showOld ? 'Hide Old' : 'Show Old';
    applyFilters();
  });

  fetchFragment();
})();
