(() => {
  function cellValue(row, columnIndex, type) {
    const cell = row.cells[columnIndex];
    const raw = cell?.dataset.sortValue ?? cell?.textContent ?? "";
    return type === "number" ? Number(raw) || 0 : raw.trim().toLocaleLowerCase();
  }

  function sortTable(header) {
    const table = header.closest("table[data-log-sortable]");
    const body = table?.tBodies?.[0];
    if (!body) return;

    const headers = Array.from(header.parentElement.children);
    const columnIndex = headers.indexOf(header);
    const type = header.dataset.sortType || "number";
    const current = header.getAttribute("aria-sort");
    const direction = current === "none"
      ? (type === "text" ? "ascending" : "descending")
      : (current === "ascending" ? "descending" : "ascending");
    const multiplier = direction === "ascending" ? 1 : -1;

    const rows = Array.from(body.rows);
    rows.sort((left, right) => {
      const leftValue = cellValue(left, columnIndex, type);
      const rightValue = cellValue(right, columnIndex, type);
      if (type === "text") {
        return leftValue.localeCompare(rightValue, undefined, { sensitivity: "base" }) * multiplier;
      }
      return (leftValue - rightValue) * multiplier;
    });

    headers.forEach((item) => item.setAttribute("aria-sort", "none"));
    header.setAttribute("aria-sort", direction);
    rows.forEach((row) => body.appendChild(row));
  }

  document.addEventListener("click", (event) => {
    const header = event.target.closest("th[data-log-sort]");
    if (header) sortTable(header);
  });
})();
