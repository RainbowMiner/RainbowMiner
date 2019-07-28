// fix bootstrap-table icons
window.icons = {
  refresh: 'fa-sync',
  toggle: 'fa-id-card',
  columns: 'fa-columns',
  clear: 'fa-trash'
};

function timeSince(date) {
  var seconds = Math.floor((new Date() - date) / 1000);
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
 
function formatBTC(value) {
  return parseFloat(value).toFixed(8);
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

function formatPrices(data) {
    return (data * 1000000000).toFixed(10);
}

function formatDate(data) {
    return timeSince(new Date(data));
}

function formatBLK(data) {
    if (typeof data == "undefined") return data;
    if (!data) return "Infinity"
    data = 24 / data * 60
    return data.toFixed(1)
}

function formatTSL(data) {
    if (typeof data == "undefined") return data;
    data = data / 60
    return data.toFixed(1)
}

function formatAlgorithm(data) {
    return (globalconfig && globalconfig.EnableAlgorithmMapping && globalconfig.AlgorithmMap[data]) ? globalconfig.AlgorithmMap[data] : data;
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
  

function setCookie(cname, cvalue, exdays) {
    var d = new Date();
    d.setTime(d.getTime() + ((exdays==-1? 3650 : exdays) * 24 * 60 * 60 * 1000));
    var expires = "expires=" + d.toUTCString();
    document.cookie = cname + "=" + cvalue + ";" + expires + ";path=/";
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