(() => {
  const onlineEndpoint = "/stats/online_summary.php";

  const element = (reference) => {
    if (!reference) return null;
    return typeof reference === "string" ? document.getElementById(reference) : reference;
  };

  const normalizeOnline = (payload = {}) => {
    let count = Number(payload.player_count ?? payload.online_players ?? payload.players ?? 0);
    let max = Number(
      payload.visible_max ?? payload.visible_max_players ?? payload.max_players ?? payload.max ?? 32
    );

    if (!Number.isFinite(count) || count < 0) count = 0;
    if (!Number.isFinite(max) || max <= 0) max = 32;

    return {
      player_count: count,
      visible_max: max,
      updated: Number(payload.updated) || Math.floor(Date.now() / 1000)
    };
  };

  const applyOnline = (payload, labelReference, mirrorReference = null, writeCache = true) => {
    const summary = normalizeOnline(payload);
    const label = summary.player_count + " / " + summary.visible_max;
    const labelEl = element(labelReference);
    const mirrorEl = element(mirrorReference);

    if (labelEl) labelEl.textContent = label;
    if (mirrorEl) mirrorEl.textContent = label;
    if (writeCache) window.WTOnlineCountCache?.write?.(summary);

    return summary;
  };

  const applyCachedOnline = (labelReference, mirrorReference = null) => {
    const labelEl = element(labelReference);
    const mirrorEl = element(mirrorReference);
    return window.WTOnlineCountCache?.apply?.(labelEl, mirrorEl) || false;
  };

  const updateOnline = async (labelReference, mirrorReference = null, onUpdate = null) => {
    if (!element(labelReference) && !element(mirrorReference)) return null;

    try {
      const response = await fetch(onlineEndpoint, { cache: "no-store" });
      if (!response.ok) throw new Error("Online summary request failed");
      const summary = applyOnline(await response.json(), labelReference, mirrorReference);
      if (typeof onUpdate === "function") onUpdate(summary);
      return summary;
    } catch (_error) {
      applyCachedOnline(labelReference, mirrorReference);
      return null;
    }
  };

  const updateChat = (labelReference) => {
    const labelEl = element(labelReference);
    if (!labelEl) return Promise.resolve(null);
    return window.WTChatAgeLabel?.update?.(labelEl) || Promise.resolve(null);
  };

  const start = ({
    online = null,
    onlineMirror = null,
    chat = null,
    onOnline = null,
    onlineInterval = 10000,
    chatInterval = 60000
  } = {}) => {
    const timers = [];

    if (online) {
      applyCachedOnline(online, onlineMirror);
      updateOnline(online, onlineMirror, onOnline);
      timers.push(window.setInterval(
        () => updateOnline(online, onlineMirror, onOnline),
        onlineInterval
      ));
    }

    if (chat) {
      window.WTChatAgeLabel?.apply?.(element(chat));
      updateChat(chat);
      timers.push(window.setInterval(() => updateChat(chat), chatInterval));
    }

    return () => timers.forEach((timer) => window.clearInterval(timer));
  };

  window.WTNavStatus = {
    normalizeOnline,
    applyOnline,
    applyCachedOnline,
    updateOnline,
    updateChat,
    start
  };
})();
