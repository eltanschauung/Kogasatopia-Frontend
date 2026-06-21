(() => {
  const WTChatAgeLabel = {
    endpointBase: "/stats/chat.php?limit=1&alerts_only=1",
    key: "wt_chat_age_v1",
    lastText: null,
    latestCreatedAt: 0,
    requestSeq: 0,

    read() {
      try {
        const raw = window.localStorage?.getItem(this.key);
        if (!raw) return null;
        const parsed = JSON.parse(raw);
        const createdAt = Number(parsed?.created_at || 0);
        if (!Number.isFinite(createdAt) || createdAt <= 0) return null;
        return { created_at: createdAt, updated: Number(parsed?.updated) || 0 };
      } catch (_err) {
        return null;
      }
    },

    write(createdAt) {
      try {
        const timestamp = Number(createdAt || 0);
        if (!Number.isFinite(timestamp) || timestamp <= 0) return false;
        this.latestCreatedAt = Math.max(Number(this.latestCreatedAt || 0), timestamp);
        window.localStorage?.setItem(this.key, JSON.stringify({
          created_at: this.latestCreatedAt,
          updated: Math.floor(Date.now() / 1000)
        }));
        return true;
      } catch (_err) {
        return false;
      }
    },

    clear() {
      this.latestCreatedAt = 0;
      this.lastText = null;
      try {
        window.localStorage?.removeItem(this.key);
      } catch (_err) {
        // ignore cache errors
      }
    },

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
      if (!labelEl) return false;
      const cached = this.read();
      const createdAt = Math.max(
        Number(this.latestCreatedAt || 0),
        Number(cached?.created_at || 0)
      );
      if (createdAt <= 0) return false;
      this.latestCreatedAt = createdAt;
      this.lastText = this.textForCreatedAt(createdAt);
      labelEl.textContent = this.lastText;
      return true;
    },

    async update(labelEl) {
      if (!labelEl) return null;
      this.apply(labelEl);
      const requestId = ++this.requestSeq;

      try {
        const res = await fetch(`${this.endpointBase}&t=${Date.now()}`, { cache: "no-store" });
        if (!res.ok) throw new Error("Request failed");
        const payload = await res.json();
        const messages = Array.isArray(payload?.messages) ? payload.messages : [];
        const last = this.newestMessage(messages);

        let nextText = "Last msg. --";
        let nextCreatedAt = 0;
        if (last) {
          nextCreatedAt = Math.max(Number(last.created_at || 0), Number(this.latestCreatedAt || 0));
          nextText = this.textForCreatedAt(nextCreatedAt);
        }

        if (requestId !== this.requestSeq) return this.lastText;
        if (nextCreatedAt > 0) this.write(nextCreatedAt);
        else this.clear();
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
