(() => {
  function initFlashClose(root = document) {
    root?.querySelectorAll?.("[role=alert][data-flash]").forEach((el) => {
      if (el.dataset.flashCloseBound === "1") return;
      el.dataset.flashCloseBound = "1";
      el.addEventListener("click", () => {
        el.setAttribute("hidden", "");
      });
    });
  }

  window.KogasaFlash = { init: initFlashClose };

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", () => initFlashClose(), { once: true });
  } else {
    initFlashClose();
  }
})();
