((global) => {
  const flagBaseUrl = "https://bantculture.com/static/flags/";

  const numberFormat = (value) => {
    try {
      return new Intl.NumberFormat().format(Number(value || 0));
    } catch (_error) {
      return String(value || 0);
    }
  };

  const fixed = (value, digits = 1) => {
    const number = Number(value || 0);
    return Number.isFinite(number) ? number.toFixed(digits) : "0";
  };

  const escapeHtml = (value) => String(value ?? "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");

  const formatPlaytime = (seconds) => {
    const totalSeconds = Math.max(0, Number(seconds) || 0);
    const totalMinutes = Math.floor(totalSeconds / 60);
    const hours = Math.floor(totalMinutes / 60);
    const minutes = totalMinutes % 60;
    if (hours > 0) return hours + "h " + minutes + "m";
    return Math.max(minutes, 1) + "m";
  };

  const normalizeFlagCode = (code) => String(code || "")
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9_-]/g, "");

  const flagImageUrl = (code) => {
    const normalized = normalizeFlagCode(code);
    return normalized ? flagBaseUrl + encodeURIComponent(normalized) + ".png" : "";
  };

  const flagImageHtml = (code, title, className = "server-flag") => {
    const normalized = normalizeFlagCode(code);
    if (!normalized) return "";
    const label = String(title || normalized);
    return '<img class="' + escapeHtml(className) + '" src="' + flagImageUrl(normalized) +
      '" alt="' + escapeHtml(normalized.toUpperCase()) + '" title="' + escapeHtml(label) + '">';
  };

  const createFlagImage = (code, title, className = "server-flag") => {
    const normalized = normalizeFlagCode(code);
    if (!normalized) return null;

    const flag = document.createElement("img");
    flag.className = className;
    flag.alt = normalized.toUpperCase();
    flag.src = flagImageUrl(normalized);
    flag.title = String(title || normalized);
    return flag;
  };

  const serverFlagsHtml = (server) => {
    const flags = [];
    const countryCode = normalizeFlagCode(server?.country_code);
    if (countryCode) {
      flags.push(flagImageHtml(countryCode, server?.country_name || countryCode.toUpperCase()));
    }
    if (Array.isArray(server?.extra_flags)) {
      server.extra_flags.forEach((flag) => {
        const normalized = normalizeFlagCode(flag);
        if (normalized) flags.push(flagImageHtml(normalized, String(flag || normalized)));
      });
    }
    return flags.join("");
  };

  global.KogasaUI = Object.freeze({
    numberFormat,
    fixed,
    escapeHtml,
    formatPlaytime,
    normalizeFlagCode,
    flagImageUrl,
    flagImageHtml,
    createFlagImage,
    serverFlagsHtml
  });
})(window);
