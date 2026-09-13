(() => {
  const root = document.documentElement;
  const token = root.dataset.weaponsSession;
  const container = document.getElementById("button-container");
  if (!token || !container) return;

  const delay = (milliseconds) => new Promise((resolve) => setTimeout(resolve, milliseconds));
  let busy = false;

  function cards() {
    return [...container.querySelectorAll("a.on[data-weapon-uid]")];
  }

  function setEquipped(card, equipped) {
    card.classList.toggle("is-equipped", equipped);
    card.setAttribute("aria-pressed", equipped ? "true" : "false");
    const label = card.querySelector(".btn-label");
    if (label) label.textContent = equipped ? "Equipped" : card.dataset.weaponName;
  }

  function applyLoadout(equippedUids) {
    const equipped = new Set(equippedUids || []);
    cards().forEach((card) => setEquipped(card, equipped.has(card.dataset.weaponUid)));
  }

  async function queueAction(card, desiredEquipped) {
    const response = await fetch(
      `/api/weapons/panel/${encodeURIComponent(token)}/actions`,
      {
        method: "POST",
        headers: { "accept": "application/json", "content-type": "application/json" },
        body: JSON.stringify({
          weapon_uid: card.dataset.weaponUid,
          equipped: desiredEquipped
        })
      }
    );
    if (!response.ok) throw new Error("action rejected");
    const queued = await response.json();

    for (let attempt = 0; attempt < 40; attempt += 1) {
      await delay(125);
      const statusResponse = await fetch(
        `/api/weapons/panel/${encodeURIComponent(token)}/actions/${encodeURIComponent(queued.action_id)}`,
        { headers: { "accept": "application/json" }, cache: "no-store" }
      );
      if (!statusResponse.ok) throw new Error("action unavailable");
      const action = await statusResponse.json();
      if (action.status === "pending") continue;
      if (action.status !== "success") throw new Error(action.error || "action failed");
      return action.equipped_uids;
    }

    throw new Error("action timed out");
  }

  container.addEventListener("click", async (event) => {
    const card = event.target.closest("a.on[data-weapon-uid]");
    if (!card || !container.contains(card)) return;
    event.preventDefault();
    if (busy) return;

    const previous = cards()
      .filter((item) => item.classList.contains("is-equipped"))
      .map((item) => item.dataset.weaponUid);
    const desiredEquipped = !card.classList.contains("is-equipped");
    busy = true;
    card.classList.add("is-pending");
    setEquipped(card, desiredEquipped);

    try {
      applyLoadout(await queueAction(card, desiredEquipped));
    } catch (_error) {
      applyLoadout(previous);
    } finally {
      card.classList.remove("is-pending");
      busy = false;
    }
  });
})();
