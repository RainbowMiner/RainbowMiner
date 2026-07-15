// RainbowMiner web UI shared library v2.0
// Consolidates former utilities-1.9.js + inline ConfigLoader, adds theme and
// clipboard helpers. Classic (non-module) script: bootstrap-table resolves
// formatters/sorters by name on window.

"use strict";

/* ---------------------------------------------------------------------------
 * Theme (localStorage + prefers-color-scheme), applied immediately on load.
 * Migrates the legacy "rbm-theme" cookie once, then the cookie is unused.
 * ------------------------------------------------------------------------- */
const RbmTheme = (function () {
    const KEY = "rbm-theme";

    function fromCookie() {
        const m = document.cookie.match(/(?:^|;\s*)rbm-theme=([^;]*)/);
        return m ? decodeURIComponent(m[1]) : "";
    }

    function get() {
        let t = localStorage.getItem(KEY);
        if (!t) {
            t = fromCookie(); // one-time migration from the old cookie
            if (t) localStorage.setItem(KEY, t);
        }
        if (t !== "dark" && t !== "light") {
            t = window.matchMedia && window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light";
        }
        return t;
    }

    function set(t) {
        if (t !== "dark") t = "light";
        localStorage.setItem(KEY, t);
        apply(t);
    }

    function apply(t) {
        document.documentElement.setAttribute("data-bs-theme", t === "dark" ? "dark" : "light");
    }

    apply(get()); // pre-paint: this script loads in <head>, before first render

    return { get: get, set: set };
})();

/* ---------------------------------------------------------------------------
 * Clipboard helper.
 * navigator.clipboard needs a secure context: that includes http://localhost
 * but NOT http://<LAN-IP>, which is how remote rigs are usually opened -
 * hence the hidden-textarea fallback.
 * ------------------------------------------------------------------------- */
function copyToClipboard(text) {
    if (navigator.clipboard && window.isSecureContext) {
        return navigator.clipboard.writeText(text);
    }
    return new Promise(function (resolve, reject) {
        const ta = document.createElement("textarea");
        ta.value = text;
        ta.style.position = "fixed";
        ta.style.opacity = "0";
        document.body.appendChild(ta);
        ta.focus();
        ta.select();
        try {
            document.execCommand("copy") ? resolve() : reject(new Error("copy failed"));
        } catch (err) {
            reject(err);
        } finally {
            ta.remove();
        }
    });
}

/* ---------------------------------------------------------------------------
 * ConfigLoader (moved from parts/head.html inline script)
 * ------------------------------------------------------------------------- */
var selected_currency = { currency: null, rate: 0 };

const ConfigLoader = (function () {
    let config = null;
    let ready = false;
    let resolvePromise, rejectPromise;
    const configPromise = new Promise((resolve, reject) => {
        resolvePromise = resolve;
        rejectPromise = reject;
    });

    const MAX_ATTEMPTS = 10;
    const RETRY_DELAY_MS = 1000;
    const REFRESH_INTERVAL_MS = 300000;

    function loadConfig(attempt) {
        fetch("/info")
        .then(response => {
            if (!response.ok) throw new Error("Server responded with error");
            return response.json();
        })
        .then(data => {
            if (!data.Version) {
                if (attempt < MAX_ATTEMPTS) {
                    setTimeout(() => loadConfig(attempt + 1), RETRY_DELAY_MS);
                } else {
                    rejectPromise("Failed to load config: Version missing after " + MAX_ATTEMPTS + " attempts.");
                    console.error("ConfigLoader error: Version missing in /info response.");
                }
                return;
            }

            config = data;

            // Optional globals
            window.nDecimalSeparator = config.DecSep;
            window.tDecimalSeparator = config.DecSep === "." ? "," : ".";

            ready = true;

            resolvePromise(config);
            setTimeout(() => loadConfig(1), REFRESH_INTERVAL_MS); // Periodic refresh
        })
        .catch(error => {
            if (attempt < MAX_ATTEMPTS) {
                console.warn("Retrying to fetch /info... attempt", attempt + 1);
                setTimeout(() => loadConfig(attempt + 1), RETRY_DELAY_MS);
            } else {
                rejectPromise("Failed to fetch /info after " + MAX_ATTEMPTS + " attempts.");
                console.error("ConfigLoader error:", error);
            }
        });
    }

    loadConfig(1);

    return {
        getConfig: () => config,
        isReady: () => ready,
        whenReady: () => configPromise
    };
})();

/* ---------------------------------------------------------------------------
 * Formatters and sorters (unchanged from utilities-1.9.js)
 * ------------------------------------------------------------------------- */
function timeSince(date) {
  var seconds = Math.max(Math.floor((new Date() - date) / 1000),0);
  var interval = Math.floor(seconds / 31536000);
  if (interval > 1) {
    return interval + " years ago";
  }
  interval = Math.floor(seconds / 2592000);
  if (interval > 1) {
    return interval + " months ago";
  }
  interval = Math.floor(seconds / 86400);
  if (interval > 1) {
    return interval + " days ago";
  }
  interval = Math.floor(seconds / 3600);
  if (interval > 1) {
     return interval + " hours ago";
  }

  interval = Math.floor(seconds / 60);
  if (interval > 1) {
    return interval + " minutes ago";
  }
  return Math.floor(seconds) + " seconds ago";
}

function formatHashRateValue(value) {
  var sizes = ['H/s','KH/s','MH/s','GH/s','TH/s'];
  if (value == 0) return '0 H/s';
  if (isNaN(value)) return '-';
  var i = Math.floor(Math.log(value) / Math.log(1000));
  if (i<0) {i=0;} else if (i>4) {i=4;}
  return parseFloat((value / Math.pow(1000, i)).toFixed(2)) + ' ' + sizes[i];
}

function formatHashRate(value) {
  if (Array.isArray(value)) {
    return value.map(formatHashRate).toString();
  } else {
    return formatHashRateValue(value);
  }
}

function formatBTC(value,unit) {
  var m = 1, f=8;
  if (typeof unit !== "undefined" && unit != "BTC") {
    if (unit == "mBTC") {m=1000;f=5}
    else if (unit == "sat") {m=1e8;f=0}
  }
  return (parseFloat(value)*m).toFixed(f);
};

function formatmBTC(value) {
    var v = parseFloat(value) * 1000;
    return v.toFixed(5);
};

function formatArrayAsString(value) {
  return value.toString();
};

function formatMinerHashRatesAlgorithms(value) {
  return Object.keys(value).toString();
};

function formatMinerHashRatesValues(value) {
  var hashrates = [];
  for (var property in value) {
    hashrates.push(formatHashRateValue(value[property]));
  }
  return hashrates.toString();
}

function formatPower(value) {
  if (typeof value == "undefined" || value < 0) return "N/A"
  return value + " W"
}

function formatPrices(data) {
    return (data * 1000000000).toFixed(10);
}

function getSelectedCurrency() {
    if (selected_currency.currency != null && selected_currency.rate) {
        return selected_currency
    }

    const sel = document.getElementById("profit_currency");
    const opt = sel && sel.selectedOptions.length ? sel.selectedOptions[0] : null;

    var selcur = {
        rate: 1000,
        currency: opt ? opt.value : window.localStorage.getItem("currency")
    }
    if (opt) {
        selcur.rate = parseFloat(opt.dataset.rate);
    } else if (selcur.currency == "BTC") { // note: fixes the old 'curreny' typo that made this branch dead
        selcur.rate = 1
    } else if (selcur.currency == "mBTC") {
        selcur.rate = 1000
    } else if (selcur.currency == "sat") {
        selcur.rate = 1e8
    } else {
        selcur.currency = "mBTC";
        selcur.rate = 1000;
    }
    return selcur
}

function formatPricesByCurrency(data,selcur) {
    if (typeof data == "undefined" || !data) return "-";
    if (typeof selcur.currency == "undefined" || !selcur.currency) selcur = {currency: "mBTC", rate: 1000}
    if (typeof selcur.rate == "undefined" || !selcur.rate) {
        if (selcur.currency == "BTC") selcur.rate = 1
        else if (selcur.currency == "mBTC") selcur.rate = 1000
        else if (selcur.currency == "sat") selcur.rate = 1e8
        else {
            return formatPricesBTC(data);
        }
    }

    var value = parseFloat(data) * selcur.rate;

    if (selcur.currency == "BTC") {
        return value.toFixed(8).toString();
	} else if (selcur.currency == "mBTC") {
        return value.toFixed(5).toString() + '&nbsp;m';
    } else if (selcur.currency == "sat") {
        return Math.round(value);
    }
    return value.toFixed(3).toString() + '&nbsp;' + selcur.currency;
}

function formatPricesBTC(data) {
    if (typeof data == "undefined" || !data) return "-";
    var value = parseFloat(data);
    const csel = document.getElementById("profit_currency");
    var currency = (csel && csel.options.length) ? csel.value : window.localStorage.getItem("currency");
    if (currency == "BTC") {
        return value.toFixed(8).toString();
	}
    var i = Math.floor(Math.log(value) / Math.log(1000));
    var cm = "", rto = 5;
    if (i < 0) { cm = "m"; value *= 1e3; rto = 5 }
    return value.toFixed(rto).toString() + (cm ? '&nbsp;' + cm : '');
}

function formatDate(data) {
    return timeSince(new Date(data));
}

function formatUptime(uptime) {
    var uptime = parseInt(uptime);
    var d = Math.floor(uptime / 86400); uptime -= d*86400;
    var h = Math.floor(uptime / 3600); uptime -= h*3600;
    var m = Math.floor(uptime / 60); uptime -= m*60;
    return d + '.' + (h < 10 ? '0' : '') + h + ':' + (m < 10 ? '0' : '') + m + ':' + (uptime < 10 ? '0' : '') + uptime;
}

function formatBLK(data) {
    if (typeof data == "undefined") return data;
    if (data == null) return "-";
    if (!data) return "&infin;"
    data = 86400 / data
    if (data >= 86400) {
        if (data >= 31536000) {data = "&gt;1 y"}
        else if (data >= 15768000) {data = "&gt;6 mo"}
        else if (data >= 2628000) {data = "&gt;1 mo"}
        else if (data >= 604800) {data = "&gt;1 w"}
        else {
            data /= 86400
            data = data.toFixed(1) + " d"
        }
    }
    else if (data >= 3600) {
        data /= 3600
        data = data.toFixed(1) + " h"
    }
    else if (data >= 60) {
        data /= 60
        data = data.toFixed(1) + " m"
    }
    else {
        data = data.toFixed(1) + " s"
    }

    return data.replace(".0 ","&nbsp;").replace(" ","&nbsp;")
}

function formatTSL(data) {
    if (typeof data == "undefined") return data;
    data = data / 60
    return data.toFixed(1)
}

function formatAlgorithm(data) {
    const cfg = ConfigLoader.getConfig();
    return (cfg && cfg.EnableAlgorithmMapping && cfg.AlgorithmMap[data]) ? cfg.AlgorithmMap[data] : data;
}

// Show the shared modal. Body is text by default; pass asHtml=true for
// trusted server-generated markup (e.g. ps1 script output).
function rbmShowModal(body, title, asHtml) {
    const modal = document.getElementById('myModal');
    if (asHtml) modal.querySelector('.modal-body').innerHTML = body;
    else modal.querySelector('.modal-body').textContent = body;
    modal.querySelector('.modal-title').textContent = title;
    bootstrap.Modal.getOrCreateInstance(modal).show();
}

// Serialize a form and POST it to /saveconfig, honoring the config lock.
// Wire format is identical to jQuery's $(form).serialize().
async function rbmSubmitConfig(form, cfg, afterSave) {
    if (cfg.IsLocked) {
        rbmShowModal('To be able to save, manually set parameter "APIlockConfig" to "0" in config.txt', 'Warning: config lock is enabled');
        return;
    }
    try {
        const response = await fetch("/saveconfig", {
            method: "POST",
            headers: { 'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8' },
            body: new URLSearchParams(new FormData(form)).toString()
        });
        const data = await response.json();
        if (data.Success) {
            rbmShowModal('RainbowMiner will pick up the new configuration after the current round has ended.', 'Configuration saved!');
        } else {
            rbmShowModal('Something went wrong or the configuration is locked via APILockConfig in config.txt', 'Configuration NOT saved!');
        }
        if (afterSave) afterSave(data);
    } catch (error) {
        console.error("saveconfig:", error);
    }
}

// Show/hide elements via inline display (the hidden attribute loses against
// Bootstrap display classes like .row/.d-flex).
function rbmToggleDisplay(selector, visible) {
    for (const el of document.querySelectorAll(selector)) {
        el.style.display = visible ? '' : 'none';
    }
}

// Escape a string for safe insertion into HTML
function esc(s) {
    return String(s).replace(/[&<>"']/g, function (c) {
        return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
    });
}

function detailFormatter(index, row) {
  // JSON.stringify escapes quotes but not angle brackets - esc() both,
  // since rows may contain data reported by remote workers.
  var html = [];
  for (const [key, value] of Object.entries(row)) {
    if (key.startsWith('_rbm')) continue; // internal table-layer state
    html.push('<p class="mb-0"><b>' + esc(key) + ':</b> ' + esc(JSON.stringify(value)) + '</p>');
  }
  return html.join('');
}

function formatBytes(bytes) {
  var decimals = 2
  if(bytes == 0) return '0 Bytes';
  var k = 1024,
    dm = decimals || 2,
    sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB', 'PB', 'EB', 'ZB', 'YB'],
    i = Math.floor(Math.log(bytes) / Math.log(k));
  return parseFloat((bytes / Math.pow(k, i)).toFixed(dm)) + ' ' + sizes[i];
}

function formatVersion(version) {
    return version.Major + '.' + version.Minor + '.' + version.Build + '.' +version.Revision
}

function sortNumber(a,b,rowA,rowB) {
    a = Number(a.replace(/[^0-9.-]+/g,""))
    b = Number(b.replace(/[^0-9.-]+/g,""))

    if (a > b) return 1
    if (a < b) return -1
    return 0
}

