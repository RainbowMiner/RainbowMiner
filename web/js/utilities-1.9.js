﻿// fix bootstrap-table icons
window.icons = {
  refresh: 'fa-sync',
  toggle: 'fa-id-card',
  columns: 'fa-columns',
  clear: 'fa-trash'
};

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
  hashrates = [];
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

    var selcur = {
        rate: 1000,
        currency: ($("#profit_currency option").length)? $("#profit_currency option:selected").val() : window.localStorage.getItem("currency")
    }
    if ($("#profit_currency option").length) {
        selcur.rate = parseFloat($("#profit_currency option[value='"+selcur.currency+"']").attr("rate"));
    } else if (selcur.curreny == "BTC") {
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
    var currency = ($("#profit_currency option").length)? $("#profit_currency option:selected").val() : window.localStorage.getItem("currency");
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

function detailFormatter(index, row) {
  var html = [];
  $.each(row, function (key, value) {
    html.push('<p class="mb-0"><b>' + key + ':</b> ' + JSON.stringify(value) + '</p>');
  });
  return html.join('');
}

function formatBytes(bytes) {
  decimals = 2
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

function setCookie(cname, cvalue, exdays) {
    var expires = "";
    if (exdays) {
        var d = new Date();
        d.setTime(d.getTime() + ((exdays==-1? 3650:exdays) * 24 * 60 * 60 * 1000));
        expires = "expires=" + d.toUTCString() + ";";
    }
    document.cookie = cname + "=" + cvalue + ";SameSite=Lax;" + expires + "path=/";
}

function getCookie(cname) {
    var name = cname + "=";
    var decodedCookie = decodeURIComponent(document.cookie);
    var ca = decodedCookie.split(';');
    for (var i = 0; i < ca.length; i++) {
        var c = ca[i];
        while (c.charAt(0) == ' ') {
            c = c.substring(1);
        }
        if (c.indexOf(name) == 0) {
            return c.substring(name.length, c.length);
        }
    }
    return "";
}

// Sort options in the select filter
function sortFilterOptions(element_id) {
    // Iterate over each select filter generated by filter-control
    $(element_id).on('post-body.bs.table', function () {
        $('.bootstrap-table .filter-control select').each(function () {
            const select = $(this);

            // Extract options as an array
            const options = select.find('option').toArray().map(option => ({
                value: option.value,
                text: option.text
            }));

            // Sort options alphabetically by text
            options.sort((a, b) => a.text.localeCompare(b.text));

            // Rebuild the select with sorted options
            select.empty(); // Clear existing options
            options.forEach(option => {
                select.append(new Option(option.text, option.value));
            });
        });
    });
}
