// RainbowMiner table layer v1.0 (Phase 4B)
// Replaces bootstrap-table with Tabulator 6.x while keeping the declarative
// <table class="rbm-table-init" data-url=...><th data-field=...> page markup.
// One translation layer instead of 16 hand-migrated tables.
//
// ---------------------------------------------------------------------------
// SCROLL MODEL - please read before changing any of the four settings below.
//
// Tabulator is designed around a table that is its own scroll container: a
// fixed height with internal scrolling. We deliberately do NOT use that model,
// because our tables are full-height page content (like bootstrap-table's
// were) and detail rows must be able to expand the page. The document is the
// scroller, not the table.
//
// That decision is implemented by FOUR pieces that only work together:
//   1. css/dashboard.css: .tabulator + .tabulator-tableholder are forced to
//      height:auto !important / max-height:none !important (beats the inline
//      height Tabulator pins at render time), holder overflow-y:hidden.
//   2. renderVertical: "basic"  - no vertical virtual DOM, the container
//      height simply follows its content.
//   3. autoResize: false       - Tabulator must never redraw itself on a
//      window resize. On phones the URL bar hides/shows while scrolling,
//      which fires resize continuously; each redraw rewrote the document
//      height mid-gesture and the browser clamped the scroll position, i.e.
//      the page jumped to the top while the user was just scrolling.
//   4. the central resize listener below, which redraws only when the window
//      WIDTH changed (URL bar wobble changes the height only; a rotation or
//      a desktop window resize changes the width).
//
// Consequence: Tabulator's own scroll preservation (replaceData keeps the
// holder's scroll) does nothing for us - it knows only about the holder, not
// about the document. Refresh stability is therefore handled in
// refreshKeepScroll(): block redraw -> swap data atomically -> restore the
// horizontal position. Nothing here ever scrolls the page vertically.
//
// Re-enabling autoResize, dropping the height:auto CSS, or switching the
// renderer back to "virtual" will bring the mobile scroll jumps back.
// ---------------------------------------------------------------------------

"use strict";

const RbmTables = (function () {

    const registry = new Map();   // container element -> Tabulator instance
    const pending = new Map();     // '#id' -> [resolve callbacks] waiting for creation

    // --- user interaction tracking ------------------------------------------
    // Swapping table data while the user is touching or (momentum-)scrolling
    // kills the gesture and causes visible jumps. Track the last interaction
    // and let auto-refresh wait for a quiet moment (data a few seconds stale
    // beats a page that fights the user's finger).
    let lastInteraction = 0;
    const markInteraction = () => { lastInteraction = Date.now(); };
    for (const ev of ["touchstart", "touchmove", "wheel", "pointerdown", "keydown", "scroll"]) {
        window.addEventListener(ev, markInteraction, { passive: true, capture: true });
    }
    function userIsInteracting() {
        // iOS momentum scrolling keeps firing scroll events until it settles,
        // so this also covers the glide after the finger lifts
        return Date.now() - lastInteraction < 1500;
    }

    // --- resize handling ----------------------------------------------------
    // Tabulator's autoResize redraws the whole table on every window resize.
    // On phones the URL bar hides/shows while scrolling, which fires resize
    // constantly - each redraw rewrites the document height mid-gesture and
    // the browser clamps the scroll position (page jumps to the top). So
    // autoResize is off (see createTable) and we redraw only when the width
    // really changed: URL bar wobble changes the height only, an orientation
    // change or a desktop window resize changes the width.
    let lastWidth = window.innerWidth;
    let resizeTimer = null;
    window.addEventListener("resize", () => {
        if (window.innerWidth === lastWidth) return; // height-only: ignore
        lastWidth = window.innerWidth;
        clearTimeout(resizeTimer);
        resizeTimer = setTimeout(() => {
            for (const table of registry.values()) {
                try { table.redraw(true); } catch (e) {}
            }
        }, 250);
    }, { passive: true });

    function resolveFn(name) {
        return (typeof name === "string" && typeof window[name] === "function") ? window[name] : null;
    }

    // bootstrap-table style value comparison: numeric when both values parse
    // as finite numbers (the API delivers many numbers as strings, e.g.
    // Profit), string compare otherwise. Tabulator's auto-detected sorter
    // treats numeric strings as non-comparable, which made those columns
    // silently un-sortable.
    function smartCompare(a, b) {
        const na = parseFloat(a), nb = parseFloat(b);
        if (!isNaN(na) && !isNaN(nb) && isFinite(a) && isFinite(b)) {
            return na - nb;
        }
        return String(a === null || a === undefined ? "" : a)
            .localeCompare(String(b === null || b === undefined ? "" : b));
    }

    /* ------------------------------------------------------------------ */
    /* Attribute parsing                                                    */
    /* ------------------------------------------------------------------ */

    // <th data-*> -> Tabulator column definition
    function parseColumn(th) {
        const d = th.dataset;

        // bootstrap-table row-select column
        if (d.checkbox === "true") {
            return {
                formatter: "rowSelection",
                titleFormatter: undefined, // header select-all not used (checkbox-header="false")
                hozAlign: "center",
                headerSort: false,
                width: 44,
                minWidth: 44, // must beat the global minWidth in columnDefaults
                cssClass: "rbm-select"
            };
        }

        const col = {
            title: th.textContent.trim(),
            field: d.field,
            headerSort: d.sortable === "true"
        };

        if (d.align) col.hozAlign = d.align;
        if (d.titleTooltip) col.headerTooltip = d.titleTooltip;

        // formatter adapter: bootstrap-table signature (value, row, index) -> html/string
        const fmt = resolveFn(d.formatter);
        if (fmt) {
            col.formatter = (cell) => fmt(cell.getValue(), cell.getRow().getData(), cell.getRow().getPosition());
        }

        // sorter adapter: bootstrap-table signature (a, b, rowA, rowB)
        const srt = resolveFn(d.sorter);
        if (srt) {
            col.sorter = (a, b, aRow, bRow) => srt(a, b, aRow.getData(), bRow.getData());
        }

        // header filters (bootstrap-table filter-control)
        if (d.filterControl === "select") {
            col.headerFilter = "list";
            col.headerFilterParams = { valuesLookup: true, sort: "asc", clearable: true };
            col.headerFilterFunc = (d.filterStrictSearch === "true" || d.filterStricSearch === "true") ? "=" : "like";
        } else if (d.filterControl === "input") {
            col.headerFilter = "input";
            col.headerFilterFunc = "like";
        }

        // footer totals (bootstrap-table footer-formatter, signature: function (data) with this.field)
        const foot = resolveFn(d.footerFormatter);
        if (foot && col.field) {
            col.bottomCalc = (values, data) => foot.call({ field: col.field }, data);
            col.bottomCalcFormatter = (cell) => cell.getValue(); // values are pre-formatted html/strings
        }

        return col;
    }

    // detail-view expander column (bootstrap-table data-detail-view).
    // Expansion state is stored in the row data (_rbmexpanded) and the detail
    // div is injected by the table's rowFormatter, so expanding runs through
    // Tabulator's own render/size pipeline (the supported nested-content
    // pattern) instead of post-layout DOM surgery that breaks height calc.
    function expanderColumn() {
        return {
            title: "",
            field: undefined,
            width: 44,
            minWidth: 44, // must beat the global minWidth in columnDefaults
            hozAlign: "center",
            headerSort: false,
            cssClass: "rbm-expander",
            formatter: (cell) => {
                const data = cell.getRow().getData();
                return data && data._rbmexpanded ? '<i class="bi bi-dash-square"></i>' : '<i class="bi bi-plus-square"></i>';
            },
            cellClick: (e, cell) => {
                e.stopPropagation();
                const row = cell.getRow();
                row.update({ _rbmexpanded: !row.getData()._rbmexpanded }).then(() => row.normalizeHeight());
            }
        };
    }

    /* ------------------------------------------------------------------ */
    /* Toolbar (columns dropdown, refresh, clear filters)                   */
    /* ------------------------------------------------------------------ */

    function buildToolbar(container, table, opts) {
        const bar = document.createElement("div");
        bar.className = "rbm-table-toolbar d-flex justify-content-end gap-2 mb-1";

        if (opts.showClearFilters) {
            const clear = document.createElement("button");
            clear.type = "button";
            clear.className = "btn btn-sm btn-outline-secondary";
            clear.title = "Clear filters";
            clear.innerHTML = '<i class="bi bi-funnel"></i>';
            clear.addEventListener("click", () => table.clearHeaderFilter());
            bar.appendChild(clear);
        }

        if (opts.showRefresh) {
            const refresh = document.createElement("button");
            refresh.type = "button";
            refresh.className = "btn btn-sm btn-outline-secondary";
            refresh.title = "Refresh";
            refresh.innerHTML = '<i class="bi bi-arrow-repeat"></i>';
            refresh.addEventListener("click", () => refreshKeepScroll(container, table));
            bar.appendChild(refresh);
        }

        if (opts.showColumns) {
            const wrap = document.createElement("div");
            wrap.className = "dropdown";
            const btn = document.createElement("button");
            btn.type = "button";
            btn.className = "btn btn-sm btn-outline-secondary dropdown-toggle";
            btn.setAttribute("data-bs-toggle", "dropdown");
            btn.title = "Columns";
            btn.innerHTML = '<i class="bi bi-layout-three-columns"></i>';
            const menu = document.createElement("div");
            menu.className = "dropdown-menu dropdown-menu-end p-2 rbm-columns-menu";
            wrap.append(btn, menu);
            bar.appendChild(wrap);

            // populate once the table has built its columns
            table.on("tableBuilt", () => {
                for (const column of table.getColumns()) {
                    const def = column.getDefinition();
                    if (!def.field || def.cssClass === "rbm-expander" || def.cssClass === "rbm-select") continue;
                    const id = "colvis-" + container.id + "-" + def.field;
                    const item = document.createElement("div");
                    item.className = "form-check form-switch small";
                    const input = document.createElement("input");
                    input.className = "form-check-input";
                    input.type = "checkbox";
                    input.id = id;
                    input.checked = true;
                    input.addEventListener("change", () => column.toggle());
                    const label = document.createElement("label");
                    label.className = "form-check-label";
                    label.htmlFor = id;
                    label.textContent = def.title || def.field;
                    item.append(input, label);
                    menu.appendChild(item);
                }
            });
            // keep the menu open while toggling
            menu.addEventListener("click", (e) => e.stopPropagation());
        }

        if (bar.children.length) container.parentNode.insertBefore(bar, container);
    }

    /* ------------------------------------------------------------------ */
    /* Table creation                                                       */
    /* ------------------------------------------------------------------ */

    // Programmatic entry point (also used by the markup translator).
    // el: <table> or <div> element. opts: subset of Tabulator options plus
    // rbm extras: responseHandler, detailFormatter, rowStyle, serverPagination,
    // showColumns, showRefresh, showClearFilters, cacheBust, pageList.
    function createTable(el, opts) {
        // Tabulator replaces the element's content; swap <table> for a <div>
        let container = el;
        if (el.tagName === "TABLE") {
            container = document.createElement("div");
            if (el.id) container.id = el.id;
            container.className = "rbm-table";
            el.parentNode.replaceChild(container, el);
        }

        let responseHandler = opts.responseHandler || ((d) => d);

        const columns = opts.columns.slice();
        if (opts.detailFormatter) columns.unshift(expanderColumn());

        // bootstrap-table allowed data-sort-name to reference raw data fields that
        // have no rendered column (e.g. "Profit" while the column shows "tProfit").
        // Tabulator warns and ignores those - pre-sort the data instead.
        let initialSort = opts.initialSort;
        if (initialSort && !columns.some((c) => c.field === initialSort[0].column)) {
            const field = initialSort[0].column;
            const desc = initialSort[0].dir === "desc";
            const inner = responseHandler;
            responseHandler = (d) => {
                const out = inner(d);
                if (Array.isArray(out)) {
                    out.sort((a, b) => {
                        const av = a[field], bv = b[field];
                        if (av === undefined || av === null) return 1;
                        if (bv === undefined || bv === null) return -1;
                        return smartCompare(av, bv) * (desc ? -1 : 1);
                    });
                }
                return out;
            };
            initialSort = null;
        }

        const config = {
            // fitDataStretch: size columns by content, stretch the remainder -
            // fitColumns starved narrow columns and truncated header titles
            layout: "fitDataStretch",
            // basic vertical rendering: no virtual viewport, so the container
            // grows with content (detail rows expand without an inner scrollbar)
            renderVertical: "basic",
            // no automatic redraw on resize - handled centrally above, so that
            // the mobile URL bar showing/hiding cannot trigger a re-render
            autoResize: false,
            // bootstrap-table had no column resizing - and on touch the resize
            // handles hijack the swipe gesture ("resize mode" instead of scroll)
            resizableColumns: false,
            // bootstrap-table rendered all cells as HTML and stringified arrays
            // (API fields like Pool/CoinSymbol can be arrays, one per algorithm).
            // Remote-sourced fields are esc()'d at build time.
            columnDefaults: {
                // numeric-aware default sorter (see smartCompare)
                sorter: (a, b) => smartCompare(a, b),
                // never squeeze a column below a readable width: when the
                // columns do not fit, the table scrolls horizontally instead
                // of ellipsizing content (the expander/select columns set
                // their own smaller minWidth)
                minWidth: 80,
                formatter: (cell) => {
                    const v = cell.getValue();
                    return (v === null || v === undefined) ? "" : String(v);
                }
            },
            columns: columns,
            placeholder: "No data",
            ajaxURL: opts.url,
            ajaxConfig: { headers: { "Cache-Control": "no-cache" } }
        };

        if (initialSort) config.initialSort = initialSort;

        if (opts.serverPagination) {
            // speak bootstrap-table's server dialect: limit/offset in,
            // { total, rows } out - the PowerShell API stays unchanged
            config.pagination = true;
            config.paginationMode = "remote";
            config.paginationSize = opts.paginationSize || 10;
            if (opts.pageList) config.paginationSizeSelector = opts.pageList;
            config.sortMode = "remote";
            config.dataSendParams = { page: "_rbmpage", size: "_rbmsize", sorters: "_rbmsort" };
            config.ajaxURLGenerator = (url, cfg, params) => {
                const size = params._rbmsize === true ? 0 : (params._rbmsize || opts.paginationSize || 10);
                const page = params._rbmpage || 1;
                const q = new URLSearchParams();
                if (size > 0) {
                    q.set("limit", size);
                    q.set("offset", (page - 1) * size);
                }
                const sorters = params._rbmsort;
                if (Array.isArray(sorters) && sorters.length) {
                    q.set("sort", sorters[0].field);
                    q.set("order", sorters[0].dir);
                }
                if (opts.cacheBust) q.set("_", Date.now());
                return url + (url.includes("?") ? "&" : "?") + q.toString();
            };
            config.ajaxResponse = (url, params, response) => {
                const size = params._rbmsize === true ? 0 : (params._rbmsize || opts.paginationSize || 10);
                const total = Number(response.total) || 0;
                return {
                    last_page: size > 0 ? Math.max(1, Math.ceil(total / size)) : 1,
                    data: responseHandler(response.rows || [])
                };
            };
        } else {
            if (opts.pagination) {
                config.pagination = true;
                config.paginationSize = opts.paginationSize || 10;
                if (opts.pageList) config.paginationSizeSelector = opts.pageList;
            }
            if (opts.cacheBust) {
                config.ajaxURLGenerator = (url) => url + (url.includes("?") ? "&" : "?") + "_=" + Date.now();
            }
            config.ajaxResponse = (url, params, response) => responseHandler(response);
        }

        if (opts.rowStyle || opts.detailFormatter) {
            config.rowFormatter = (row) => {
                if (opts.rowStyle) {
                    const res = opts.rowStyle(row.getData(), row.getPosition());
                    if (res && res.classes) {
                        row.getElement().classList.add(...res.classes.split(/\s+/).filter(Boolean));
                    }
                }
                if (opts.detailFormatter) {
                    const rowEl = row.getElement();
                    const existing = rowEl.querySelector(":scope > .rbm-detail");
                    if (existing) existing.remove();
                    if (row.getData()._rbmexpanded) {
                        const div = document.createElement("div");
                        div.className = "rbm-detail";
                        div.innerHTML = opts.detailFormatter(row.getPosition(), row.getData());
                        rowEl.appendChild(div);
                    }
                }
            };
        }

        if (columns.some((c) => c.cssClass === "rbm-select")) {
            config.selectableRows = true;
        }

        const table = new Tabulator(container, config);
        registry.set(container, table);

        // remember the *latest* horizontal position (not a stale snapshot):
        // restores stay correct even if the user scrolled during the fetch
        table.on("tableBuilt", () => {
            const holder = container.querySelector(".tabulator-tableholder");
            if (holder) {
                container._rbmScrollX = holder.scrollLeft;
                holder.addEventListener("scroll", () => {
                    container._rbmScrollX = holder.scrollLeft;
                }, { passive: true });
            }
        });

        if (container.id && pending.has("#" + container.id)) {
            for (const resolve of pending.get("#" + container.id)) resolve(table);
            pending.delete("#" + container.id);
        }

        buildToolbar(container, table, opts);
        return table;
    }

    // Markup translator: init one <table class="rbm-table-init"> element
    function initFromMarkup(tableEl) {
        const d = tableEl.dataset;

        const columns = [];
        for (const th of tableEl.querySelectorAll("thead th")) {
            columns.push(parseColumn(th));
        }

        const pageList = d.pageList
            ? JSON.parse(d.pageList.replace(/\ball\b/, "true").replace(/'/g, '"'))
            : null;

        return createTable(tableEl, {
            columns: columns,
            detailFormatter: (d.detailView === "true") ? resolveFn(d.detailFormatter) : null,
            url: d.url,
            responseHandler: resolveFn(d.responseHandler),
            initialSort: d.sortName ? [{ column: d.sortName, dir: d.sortOrder || "asc" }] : null,
            cacheBust: d.cache === "false",
            rowStyle: resolveFn(d.rowStyle),
            serverPagination: d.sidePagination === "server",
            pagination: d.pagination === "true",
            paginationSize: pageList ? pageList.find((x) => x !== true) : undefined,
            pageList: pageList,
            showColumns: d.showColumns === "true",
            showRefresh: d.showRefresh === "true",
            showClearFilters: d.filterShowClear === "true"
        });
    }

    // init every declarative table on the page (called from foot.html)
    function initAll() {
        for (const el of document.querySelectorAll("table.rbm-table-init")) {
            try {
                initFromMarkup(el);
            } catch (error) {
                console.error("rbm-tables init failed for", el.id, error);
            }
        }
    }

    // look up the Tabulator instance for a selector/element
    function getTable(target) {
        const el = typeof target === "string" ? document.querySelector(target) : target;
        return el ? registry.get(el) : undefined;
    }

    // Reload data without ever moving the reading position.
    //
    // Background: Tabulator is built around the table being its own scroll
    // container (fixed height, internal scrolling) - replaceData() then
    // preserves the holder's scroll natively. Our tables are full-height page
    // content instead (height:auto, so detail rows can expand), which makes
    // the *document* the scroller - something Tabulator knows nothing about.
    // During a data swap the rows leave the DOM for a moment; the document
    // can then become shorter than the viewport and the browser clamps the
    // scroll position to 0. That clamp - not any correction of ours - is what
    // threw the page back to the top.
    //
    // Two layers prevent it:
    //  1. blockRedraw()/restoreRedraw(): Tabulator keeps the existing rows in
    //     the DOM and applies the new data in one atomic redraw, so the empty
    //     transient never exists in the first place.
    //  2. A min-height pin as a safety net, released only once the rendered
    //     content is actually back to (at least) its previous height - never
    //     on an intermediate render.
    // The page is never scrolled programmatically in the vertical axis.
    function refreshKeepScroll(container, table) {
        if (container._rbmRefreshing) return Promise.resolve(); // fetch overlap guard
        container._rbmRefreshing = true;

        const pinned = container.offsetHeight;
        container.style.minHeight = pinned + "px";

        let restored = false;
        const restoreRedraw = () => {
            if (restored) return;
            restored = true;
            try { table.restoreRedraw(); } catch (e) {}
        };

        // release the pin only when the real content has caught up again
        const releasePin = () => new Promise((resolve) => {
            let frames = 0;
            const check = () => {
                const header = container.querySelector(".tabulator-header");
                const body = container.querySelector(".tabulator-table");
                const natural = (header ? header.offsetHeight : 0) + (body ? body.offsetHeight : 0);
                // caught up, or genuinely shorter data (~1s) -> stop waiting
                if (natural >= pinned - 2 || ++frames > 60) {
                    container.style.minHeight = "";
                    container._rbmRefreshing = false;
                    resolve();
                } else {
                    requestAnimationFrame(check);
                }
            };
            requestAnimationFrame(check);
        });

        try { table.blockRedraw(); } catch (e) {}

        return table.replaceData().then(() => {
            restoreRedraw();
            const holder = container.querySelector(".tabulator-tableholder");
            const x = container._rbmScrollX || 0;
            if (holder && Math.abs(holder.scrollLeft - x) > 1) holder.scrollLeft = x;
        }).catch(() => {
            restoreRedraw();
        }).finally(() => {
            restoreRedraw(); // never leave a table blocked
            return releasePin();
        });
    }

    // periodic silent refresh - deferred while the tab is hidden, while the
    // user is interacting, or while a detail row is open (replaces the
    // bootstrap-table based rbmAutoRefreshTable)
    function autoRefresh(selector, interval) {
        ConfigLoader.whenReady().then(function () {
            setInterval(function () {
                if (document.hidden) return;          // no work in background tabs
                if (userIsInteracting()) return;      // never swap mid-gesture
                const sel = selector.replace(/^table/, "").trim() || selector;
                const el = document.querySelector(sel);
                const table = getTable(sel);
                if (!el || !table) return;
                if (el.querySelector(".rbm-detail")) return; // a detail row is open
                refreshKeepScroll(el, table);
            }, interval);
        });
    }

    // promise resolving with the Tabulator instance once a table is created
    function whenReady(target) {
        const table = getTable(target);
        if (table) return Promise.resolve(table);
        return new Promise((resolve) => {
            if (!pending.has(target)) pending.set(target, []);
            pending.get(target).push(resolve);
        });
    }

    // find the RowComponent whose rendered element contains el
    function rowFromElement(table, el) {
        const rowEl = el.closest(".tabulator-row");
        if (!rowEl) return undefined;
        return table.getRows().find((r) => r.getElement() === rowEl);
    }

    return {
        createTable: createTable,
        initFromMarkup: initFromMarkup,
        initAll: initAll,
        getTable: getTable,
        whenReady: whenReady,
        rowFromElement: rowFromElement,
        autoRefresh: autoRefresh
    };
})();

// Back-compat shim: keep the old helper name used across pages
function rbmAutoRefreshTable(selector, interval) {
    RbmTables.autoRefresh(selector, interval);
}
