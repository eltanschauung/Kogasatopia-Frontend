(() => {
  const classAliases = {
    demo: "demoman",
    engi: "engineer",
    all: "all_class"
  };

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

  function parseHashState(itemsByClass) {
    const hash = decodeURIComponent(window.location.hash.slice(1)).trim().toLowerCase();
    if (!hash) return null;

    const parts = hash.split("-").filter(Boolean);
    const requestedClass = classAliases[parts[0]] || parts[0];
    if (!Object.prototype.hasOwnProperty.call(itemsByClass, requestedClass)) return null;

    const options = new Set(parts.slice(1));
    const revertsOnly = options.has("reverts");
    return {
      activeClass: requestedClass,
      customOnly: !revertsOnly && options.has("custom"),
      revertsOnly,
      ingame: options.has("ingame")
    };
  }

  function createTile(item) {
    const link = document.createElement("a");
    link.href = "#";
    link.className = "on";
    link.title = item.title || item.name || "";
    link.addEventListener("click", (event) => event.preventDefault());

    // Preserved for the TF2 backpack-style item frame experiment.
    // const iconFrame = document.createElement("div");
    // iconFrame.className = "tf-backpack-item-center";

    const icon = document.createElement("img");
    icon.className = "btn-icon";
    icon.src = item.icon || "";
    // iconFrame.appendChild(icon);

    const label = document.createElement("span");
    label.className = "btn-label";
    label.textContent = item.name || "";

    const typeLevel = document.createElement("span");
    typeLevel.className = "type-lvl";
    typeLevel.textContent = item.type_level || "";

    const effects = document.createElement("div");
    effects.className = "effects";

    (item.effects || []).forEach((segment) => {
      const span = document.createElement("span");
      span.className = `seg ${segment.cls || "neutral"}`;
      span.textContent = segment.text || "";
      effects.appendChild(span);
    });

    // link.append(iconFrame, label, effects);
    link.append(icon, label);
    if (item.type_level) link.append(typeLevel);
    link.append(effects);
    return link;
  }

  function createIngameGroup(label, items) {
    const section = document.createElement("section");
    section.className = "weapons-ingame-group";

    const heading = document.createElement("span");
    heading.className = "tab-button-label tab-button-label--desktop";
    heading.textContent = label;

    const divider = document.createElement("hr");
    const grid = document.createElement("div");
    grid.className = "weapons-ingame-grid";
    items.forEach((item) => grid.appendChild(createTile(item)));

    section.append(heading, divider, grid);
    return section;
  }

  function boot() {
    const payload = parsePayload();
    if (!payload || !payload.items_by_class) return;

    const classBar = $("#class-bar");
    const container = $("#button-container");
    const search = $("#search");
    const customOnly = $("#custom-only");
    const showReskins = $("#show-reskins");
    if (!classBar || !container || !search || !customOnly || !showReskins) return;

    const hashState = parseHashState(payload.items_by_class);
    const clickSound = new Audio("/info/sound/tf2-button-click.mp3");
    clickSound.preload = "auto";
    clickSound.volume = 0.5;
    customOnly.checked = hashState ? hashState.customOnly : false;
    showReskins.checked = true;
    document.documentElement.classList.toggle(
      "weapons-ingame",
      Boolean(hashState && hashState.ingame)
    );

    const state = {
      activeClass: (hashState && hashState.activeClass) || payload.active_class || "scout",
      filter: "",
      customOnly: Boolean(hashState && hashState.customOnly),
      revertsOnly: Boolean(hashState && hashState.revertsOnly),
      ingame: Boolean(hashState && hashState.ingame),
      showReskins: true,
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
        if (state.revertsOnly && item.is_custom) return;
        if (state.customOnly && !item.is_custom) return;
        if (!state.showReskins && item.is_reskin) return;
        if (state.filter && item.is_hidden) return;
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
      const groupedCustomIngame = state.ingame && state.customOnly;
      container.classList.toggle("weapons-ingame-grouped", groupedCustomIngame);

      if (groupedCustomIngame) {
        container.append(
          createIngameGroup(
            "Custom Weapons",
            items.filter((item) => !item.is_reskin)
          ),
          createIngameGroup(
            "Reskins",
            items.filter((item) => item.is_reskin)
          )
        );
        return;
      }

      if (!items.length) {
        const empty = document.createElement("div");
        empty.className = "empty";
        empty.textContent = state.revertsOnly
          ? "No weapon reverts match your filter."
          : state.customOnly
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

      playClickSound();
    }

    function playClickSound() {
      try {
        clickSound.currentTime = 0;
        clickSound.play().catch(() => {});
      } catch (_err) {}
    }

    classBar.querySelectorAll(".class-btn").forEach((btn) => {
      btn.addEventListener("click", () => setActiveClass(btn.dataset.class));
    });

    document.querySelectorAll(".home-btn, .weapons-nav .tab-button").forEach((btn) => {
      btn.addEventListener("click", () => playClickSound());
    });

    search.addEventListener("input", () => {
      state.filter = (search.value || "").trim().toLowerCase();
      renderTiles();
    });

    customOnly.addEventListener("change", () => {
      state.customOnly = customOnly.checked;
      state.revertsOnly = false;

      if (state.customOnly && !customItemsAvailableForActiveClass()) {
        const nextClass = firstClassWithCustomItems();
        if (nextClass) state.activeClass = nextClass;
      }

      syncClassButtons();
      renderTiles();
    });

    showReskins.addEventListener("change", () => {
      state.showReskins = showReskins.checked;
      renderTiles();
    });

    window.addEventListener("hashchange", () => {
      const nextHashState = parseHashState(state.itemsByClass);
      state.activeClass =
        (nextHashState && nextHashState.activeClass) || payload.active_class || "scout";
      state.filter = "";
      state.customOnly = Boolean(nextHashState && nextHashState.customOnly);
      state.revertsOnly = Boolean(nextHashState && nextHashState.revertsOnly);
      state.ingame = Boolean(nextHashState && nextHashState.ingame);
      state.showReskins = true;

      search.value = "";
      customOnly.checked = state.customOnly;
      showReskins.checked = true;
      document.documentElement.classList.toggle(
        "weapons-ingame",
        state.ingame
      );

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
