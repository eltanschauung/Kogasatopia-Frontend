(() => {
  const WTOnlineCountCache = {
    key: "wt_online_summary_v1",

    read() {
      try {
        const raw = window.localStorage?.getItem(this.key);
        if (!raw) return null;
        const parsed = JSON.parse(raw);
        const count = Number(parsed?.player_count);
        const max = Number(parsed?.visible_max);
        if (!Number.isFinite(count) || count < 0 || !Number.isFinite(max) || max <= 0) return null;
        return { player_count: count, visible_max: max, updated: Number(parsed?.updated) || 0 };
      } catch (_err) {
        return null;
      }
    },

    write(payload) {
      try {
        const count = Number(payload?.player_count ?? 0);
        const max = Number(payload?.visible_max ?? payload?.visible_max_players ?? 0);
        const updated = Number(payload?.updated ?? Math.floor(Date.now() / 1000));
        if (!Number.isFinite(count) || count < 0 || !Number.isFinite(max) || max <= 0) return;
        window.localStorage?.setItem(this.key, JSON.stringify({
          player_count: Math.max(0, count),
          visible_max: max,
          updated
        }));
      } catch (_err) {
        // ignore cache errors
      }
    },

    apply(labelEl, mirrorEl = null) {
      const cached = this.read();
      if (!cached) return false;
      const label = `${cached.player_count} / ${cached.visible_max}`;
      if (labelEl) labelEl.textContent = label;
      if (mirrorEl) mirrorEl.textContent = label;
      return true;
    }
  };

  window.WTOnlineCountCache = WTOnlineCountCache;
})();
