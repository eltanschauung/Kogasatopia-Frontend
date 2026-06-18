(() => {
  const WTChatAgeLabel = {
    endpointBase: "/stats/chat.php?limit=1&alerts_only=1",
    lastText: null,
    latestCreatedAt: 0,
    requestSeq: 0,

    format(diffSeconds) {
      if (!Number.isFinite(diffSeconds) || diffSeconds < 0) return "--";
      if (diffSeconds < 60) return "now";
      if (diffSeconds < 3600) {
        const minutes = Math.max(1, Math.floor(diffSeconds / 60));
        return `${minutes} minute${minutes === 1 ? "" : "s"} ago`;
      }
      if (diffSeconds < 86400) {
        const hours = Math.max(1, Math.floor(diffSeconds / 3600));
        return `${hours} hour${hours === 1 ? "" : "s"} ago`;
      }
      if (diffSeconds < 604800) {
        const days = Math.max(1, Math.floor(diffSeconds / 86400));
        return `${days} day${days === 1 ? "" : "s"} ago`;
      }
      const weeks = Math.floor(diffSeconds / 604800);
      if (weeks < 5) return `${weeks} week${weeks === 1 ? "" : "s"} ago`;
      const months = Math.max(1, Math.floor(diffSeconds / 2629800));
      return `${months} month${months === 1 ? "" : "s"} ago`;
    },

    newestMessage(messages) {
      return messages.reduce((latest, msg) => {
        const createdAt = Number(msg?.created_at || 0);
        const latestAt = Number(latest?.created_at || 0);
        if (!latest || createdAt > latestAt) return msg;
        if (createdAt === latestAt && Number(msg?.id || 0) > Number(latest?.id || 0)) return msg;
        return latest;
      }, null);
    },

    textForCreatedAt(createdAt, nowSeconds = Math.floor(Date.now() / 1000)) {
      const timestamp = Number(createdAt || 0);
      if (!Number.isFinite(timestamp) || timestamp <= 0) return "Last msg. --";
      return `Last msg. ${this.format(nowSeconds - timestamp)}`;
    },

    apply(labelEl) {
      if (!labelEl || !this.lastText) return false;
      labelEl.textContent = this.lastText;
      return true;
    },

    async update(labelEl) {
      if (!labelEl) return null;
      const requestId = ++this.requestSeq;

      try {
        const res = await fetch(`${this.endpointBase}&t=${Date.now()}`, { cache: "no-store" });
        if (!res.ok) throw new Error("Request failed");
        const payload = await res.json();
        const messages = Array.isArray(payload?.messages) ? payload.messages : [];
        const last = this.newestMessage(messages);

        let nextText = "Last msg. --";
        if (last) {
          const createdAt = Math.max(Number(last.created_at || 0), Number(this.latestCreatedAt || 0));
          this.latestCreatedAt = createdAt;
          nextText = this.textForCreatedAt(createdAt);
        }

        if (requestId !== this.requestSeq) return this.lastText;
        this.lastText = nextText;
        labelEl.textContent = nextText;
        return nextText;
      } catch (_err) {
        this.apply(labelEl);
        return this.lastText;
      }
    }
  };

  window.WTChatAgeLabel = WTChatAgeLabel;
})();
