(function (global) {
  "use strict";

  const gradients = {
    map: "linear-gradient(90deg, #99CCFF 0%, #99CCFF 12.5%, #6495ED 12.5%, #6495ED 25%, #FFFFE0 25%, #FFFFE0 37.5%, #FFFFFF 37.5%, #FFFFFF 62.5%, #FFFFE0 62.5%, #FFFFE0 75%, #FFC0CB 75%, #FFC0CB 87.5%, #FF69B4 87.5%, #FF69B4 100%)",
    america: "linear-gradient(90deg, #FF4040 0%, #FF4040 33.333%, #FFFFFF 33.333%, #FFFFFF 66.666%, #1E90FF 66.666%, #1E90FF 100%)",
    trans: "linear-gradient(90deg, #5BCEFA 0%, #5BCEFA 33.333%, #FFFFFF 33.333%, #FFFFFF 66.666%, #F5A9B8 66.666%, #F5A9B8 100%)",
    rainbow: "linear-gradient(90deg, #FF4040, #FFA500, #FFFF00, #3EFF3E, #99CCFF, #4B0082, #EE82EE)"
  };

  function applyNameStyle(element, style, isAdmin, playerTitle) {
    if (!element) return;

    const kind = style && String(style.kind || "").toLowerCase();
    let gradient = gradients[kind] || null;

    element.classList.remove("admin-name", "chat-name-gradient");
    element.style.removeProperty("color");
    element.style.removeProperty("--chat-name-gradient");

    if (kind === "gradient" && style.first && style.second) {
      const completion = Math.max(1, Math.min(90, Number(style.completion) || 50));
      gradient = `linear-gradient(90deg, ${style.first} 0%, ${style.second} ${completion}%, ${style.second} 100%)`;
    }

    if (kind === "triple_gradient" && style.first && style.second && style.third) {
      gradient = `linear-gradient(90deg, ${style.first} 0%, ${style.second} 50%, ${style.third} 100%)`;
    }

    if (gradient) {
      element.classList.add("chat-name-gradient");
      element.style.color = "transparent";
      element.style.setProperty("--chat-name-gradient", gradient);
    } else if (kind === "solid" && style.color) {
      element.style.color = style.color;
    } else if (isAdmin) {
      element.classList.add("admin-name");
    }

    element.title = isAdmin ? "Admin" : (playerTitle || "Player");
  }

  global.KogasaPlayerIdentity = Object.freeze({ applyNameStyle });
})(window);
