(() => {
  const KogasaTime = (() => {
    const serverTimeZone = "America/New_York";
    const userTimeZone =
      Intl.DateTimeFormat().resolvedOptions().timeZone || serverTimeZone;
    const formatterCache = new Map();

    function getFormatter(options = {}, timeZone = userTimeZone) {
      const key = JSON.stringify([timeZone, options]);
      if (!formatterCache.has(key)) {
        formatterCache.set(key, new Intl.DateTimeFormat(undefined, { timeZone, ...options }));
      }
      return formatterCache.get(key);
    }

    function modeOptions(mode) {
      switch (mode) {
        case "time":
          return { hour: "2-digit", minute: "2-digit" };
        case "log-datetime":
          return {
            year: "numeric",
            month: "2-digit",
            day: "2-digit",
            hour: "2-digit",
            minute: "2-digit",
            timeZoneName: "short"
          };
        case "short-datetime":
        default:
          return {
            month: "2-digit",
            day: "2-digit",
            hour: "2-digit",
            minute: "2-digit",
            timeZoneName: "short"
          };
      }
    }

    function formatUnix(unixSeconds, options = {}, timeZone = userTimeZone) {
      const ts = Number(unixSeconds || 0);
      if (!Number.isFinite(ts) || ts <= 0) return "";
      return getFormatter(options, timeZone).format(new Date(ts * 1000));
    }

    function timeZoneLabel() {
      if (userTimeZone === serverTimeZone) return "ET";
      return userTimeZone;
    }

    function localize(root = document) {
      const nodes = [];
      if (root?.nodeType === Node.ELEMENT_NODE && root.matches("[data-local-time]")) {
        nodes.push(root);
      }
      root?.querySelectorAll?.("[data-local-time]").forEach((node) => nodes.push(node));

      nodes.forEach((node) => {
        const ts = Number(node.dataset.localTime || 0);
        if (!Number.isFinite(ts) || ts <= 0) return;
        const mode = node.dataset.timeFormat || "short-datetime";
        const text = formatUnix(ts, modeOptions(mode));
        if (text && node.textContent !== text) node.textContent = text;

        const serverText = formatUnix(ts, modeOptions(mode), serverTimeZone);
        if (serverText) node.title = `Server time: ${serverText}`;
      });
    }

    return {
      serverTimeZone,
      userTimeZone,
      formatUnix,
      formatServerUnix(unixSeconds, options = {}) {
        return formatUnix(unixSeconds, options, serverTimeZone);
      },
      localize,
      modeOptions,
      timeZoneLabel
    };
  })();

  window.KogasaTime = KogasaTime;

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", () => KogasaTime.localize(), { once: true });
  } else {
    KogasaTime.localize();
  }
})();
