(() => {
  function $(selector, root = document) {
    return root.querySelector(selector);
  }

  function parsePayload() {
    const node = document.getElementById("info-data");
    if (!node) return null;

    try {
      return JSON.parse(node.textContent || "{}");
    } catch (_err) {
      return null;
    }
  }

  function createTile(item) {
    const link = document.createElement("a");
    link.href = "#";
    link.className = "on";
    link.title = item.title || item.name || "";
    link.addEventListener("click", (event) => event.preventDefault());

    const icon = document.createElement("img");
    icon.className = "btn-icon";
    icon.src = item.icon || "";

    const label = document.createElement("span");
    label.className = "btn-label";
    label.textContent = item.name || "";

    const effects = document.createElement("div");
    effects.className = "effects";

    (item.effects || []).forEach((segment) => {
      const span = document.createElement("span");
      span.className = `seg ${segment.cls || "neutral"}`;
      span.textContent = segment.text || "";
      effects.appendChild(span);
    });

    link.append(icon, label, effects);
    return link;
  }

  function boot() {
    const payload = parsePayload();
    if (!payload || !payload.items_by_class) return;

    const classBar = $("#class-bar");
    const container = $("#button-container");
    const search = $("#search");
    const customOnly = $("#custom-only");
    if (!classBar || !container || !search || !customOnly) return;

    const clickSound = new Audio("/info/sound/tf2-button-click.mp3");
    clickSound.preload = "auto";
    clickSound.volume = 0.5;

    const state = {
      activeClass: payload.active_class || "scout",
      filter: "",
      customOnly: false,
      itemsByClass: payload.items_by_class
    };

    function syncClassButtons() {
      classBar.querySelectorAll(".class-btn").forEach((btn) => {
        btn.classList.toggle("active", btn.dataset.class === state.activeClass);
      });
    }

    function matchingItems() {
      const classItems = state.itemsByClass[state.activeClass] || [];
      const sourceItems = state.filter ? Object.values(state.itemsByClass).flat() : classItems;
      const seen = new Set();
      const list = [];

      sourceItems.forEach((item) => {
        if (state.customOnly && !item.is_custom) return;
        if (state.filter && !(item.search || "").includes(state.filter)) return;

        const dedupeKey = item.title || item.name || JSON.stringify(item);
        if (seen.has(dedupeKey)) return;
        seen.add(dedupeKey);
        list.push(item);
      });

      return list;
    }

    function customItemsAvailableForActiveClass() {
      return (state.itemsByClass[state.activeClass] || []).some((item) => item.is_custom);
    }

    function firstClassWithCustomItems() {
      const match = Object.entries(state.itemsByClass).find(([_classKey, items]) => {
        return (items || []).some((item) => item.is_custom);
      });

      return match ? match[0] : null;
    }

    function renderTiles() {
      const items = matchingItems();
      container.innerHTML = "";

      if (!items.length) {
        const empty = document.createElement("div");
        empty.className = "empty";
        empty.textContent = state.customOnly
          ? "No custom weapons match your filter."
          : "No changes for this class match your filter.";
        container.appendChild(empty);
        return;
      }

      items.forEach((item) => container.appendChild(createTile(item)));
    }

    function setActiveClass(nextClass) {
      if (!nextClass) return;
      state.activeClass = nextClass;
      state.filter = "";
      search.value = "";
      syncClassButtons();
      renderTiles();

      try {
        clickSound.currentTime = 0;
        clickSound.play().catch(() => {});
      } catch (_err) {}
    }

    classBar.querySelectorAll(".class-btn").forEach((btn) => {
      btn.addEventListener("click", () => setActiveClass(btn.dataset.class));
    });

    search.addEventListener("input", () => {
      state.filter = (search.value || "").trim().toLowerCase();
      renderTiles();
    });

    customOnly.addEventListener("change", () => {
      state.customOnly = customOnly.checked;

      if (state.customOnly && !customItemsAvailableForActiveClass()) {
        const nextClass = firstClassWithCustomItems();
        if (nextClass) state.activeClass = nextClass;
      }

      syncClassButtons();
      renderTiles();
    });

    syncClassButtons();
    renderTiles();
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", boot, { once: true });
  } else {
    boot();
  }
})();
