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

  function parseServerState(payload) {
    const state = payload.initial_state;
    if (!state) {
      return {
        activeClass: payload.active_class || "scout",
        customOnly: false,
        revertsOnly: false,
        ingame: false
      };
    }

    return {
      activeClass: state.active_class || payload.active_class || "scout",
      customOnly: Boolean(state.custom_only),
      revertsOnly: Boolean(state.reverts_only),
      ingame: Boolean(state.ingame)
    };
  }

  function sameViewState(left, right) {
    return left.activeClass === right.activeClass
      && left.customOnly === right.customOnly
      && left.revertsOnly === right.revertsOnly
      && left.ingame === right.ingame;
  }

  function createTile(item) {
    const link = document.createElement("a");
    link.href = "#";
    link.className = "on";
    link.title = item.title || item.name || "";

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

  function sectionItems(items, reskin) {
    return items
      .filter((item) => Boolean(item.is_reskin) === reskin)
      .sort((left, right) => Number(left.display_order) - Number(right.display_order));
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

    const serverState = parseServerState(payload);
    const hashState = parseHashState(payload.items_by_class);
    const initialState = hashState || serverState;
    const clickSound = new Audio("/info/sound/tf2-button-click.mp3");
    clickSound.preload = "auto";
    clickSound.volume = 0.5;
    customOnly.checked = initialState.customOnly;
    showReskins.checked = true;
    document.documentElement.classList.toggle(
      "weapons-ingame",
      initialState.ingame
    );

    const state = {
      activeClass: initialState.activeClass,
      filter: "",
      customOnly: initialState.customOnly,
      revertsOnly: initialState.revertsOnly,
      ingame: initialState.ingame,
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

      return list.sort(
        (left, right) => Number(left.display_order) - Number(right.display_order)
      );
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
            sectionItems(items, false)
          ),
          createIngameGroup(
            "Reskins",
            sectionItems(items, true)
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

    container.addEventListener("click", (event) => {
      if (event.target.closest("a.on")) event.preventDefault();
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
    if (!sameViewState(state, serverState)) renderTiles();
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", boot, { once: true });
  } else {
    boot();
  }
})();
