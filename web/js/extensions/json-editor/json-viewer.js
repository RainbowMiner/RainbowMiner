/**
 * json-viewer (vanilla JS port)
 * Based on jQuery json-viewer by Alexandre Bodelot (MIT)
 * @link: https://github.com/abodelot/jquery.json-viewer
 * Ported for RainbowMiner: no jQuery required, same markup, CSS and behavior.
 */
(function() {
  'use strict';

  /**
   * Check if arg is either an array with at least 1 element, or a dict with at least 1 key
   * @return boolean
   */
  function isCollapsable(arg) {
    return arg instanceof Object && Object.keys(arg).length > 0;
  }

  /**
   * Check if a string represents a valid url
   * @return boolean
   */
  function isUrl(string) {
    var urlRegexp = /^(https?:\/\/|ftps?:\/\/)?([a-z0-9%-]+\.){1,}([a-z0-9-]+)?(:(\d{1,5}))?(\/([a-z0-9\-._~:/?#[\]@!$&'()*+,;=%]+)?)?$/i;
    return urlRegexp.test(string);
  }

  /**
   * Transform a json object into html representation
   * @return string
   */
  function json2html(json, options) {
    var html = '';
    if (typeof json === 'string') {
      // Escape tags and quotes
      json = json
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/'/g, '&apos;')
        .replace(/"/g, '&quot;');

      if (options.withLinks && isUrl(json)) {
        html += '<a href="' + json + '" class="json-string" target="_blank">' + json + '</a>';
      } else {
        // NOTE: the upstream jquery.json-viewer additionally prefixed every
        // rendered quote with a backslash here. Combined with JsonEditor's
        // encodeJSON (which already escapes quotes) that double-escaped
        // values and broke JSON.parse on save for any value containing a
        // double quote - removed in this port.
        html += '<span class="json-string">"' + json + '"</span>';
      }
    } else if (typeof json === 'number') {
      html += '<span class="json-literal">' + json + '</span>';
    } else if (typeof json === 'boolean') {
      html += '<span class="json-literal">' + json + '</span>';
    } else if (json === null) {
      html += '<span class="json-literal">null</span>';
    } else if (json instanceof Array) {
      if (json.length > 0) {
        html += '[<ol class="json-array">';
        for (var i = 0; i < json.length; ++i) {
          html += '<li>';
          // Add toggle button if item is collapsable
          if (isCollapsable(json[i])) {
            html += '<a href class="json-toggle"></a>';
          }
          html += json2html(json[i], options);
          // Add comma if item is not last
          if (i < json.length - 1) {
            html += ',';
          }
          html += '</li>';
        }
        html += '</ol>]';
      } else {
        html += '[]';
      }
    } else if (typeof json === 'object') {
      var keyCount = Object.keys(json).length;
      if (keyCount > 0) {
        html += '{<ul class="json-dict">';
        for (var key in json) {
          if (Object.prototype.hasOwnProperty.call(json, key)) {
            html += '<li>';
            var keyHtml = key
              .replace(/&/g, '&amp;')
              .replace(/</g, '&lt;')
              .replace(/>/g, '&gt;')
              .replace(/"/g, '&quot;');
            var keyRepr = options.withQuotes ?
              '<span class="json-string">"' + keyHtml + '"</span>' : keyHtml;
            // Add toggle button if item is collapsable
            if (isCollapsable(json[key])) {
              html += '<a href class="json-toggle">' + keyRepr + '</a>';
            } else {
              html += keyRepr;
            }
            html += ': ' + json2html(json[key], options);
            // Add comma if item is not last
            if (--keyCount > 0) {
              html += ',';
            }
            html += '</li>';
          }
        }
        html += '</ul>}';
      } else {
        html += '{}';
      }
    }
    return html;
  }

  // element siblings matching a selector (jQuery .siblings(sel) equivalent)
  function siblings(el, selector) {
    return Array.from(el.parentElement.children).filter(function(child) {
      return child !== el && child.matches(selector);
    });
  }

  // one AbortController per rendered container, so re-rendering
  // (e.g. JsonEditor.load on config switch) replaces the old listeners
  var controllers = new WeakMap();

  /**
   * Render a JSON object as a collapsible tree inside `element`.
   * @param element: target DOM element
   * @param json: a javascript object
   * @param options: an optional options hash
   */
  function jsonViewer(element, json, options) {
    // Merge user options with default options
    options = Object.assign({}, {
      collapsed: false,
      rootCollapsable: true,
      withQuotes: false,
      withLinks: true
    }, options);

    // Transform to HTML
    var html = json2html(json, options);
    if (options.rootCollapsable && isCollapsable(json)) {
      html = '<a href class="json-toggle"></a>' + html;
    }

    // Insert HTML in target DOM element
    element.innerHTML = html;
    element.classList.add('json-document');

    // Rebind: drop listeners from a previous render
    if (controllers.has(element)) controllers.get(element).abort();
    var controller = new AbortController();
    controllers.set(element, controller);

    element.addEventListener('click', function(event) {
      // Simulate click on toggle button when placeholder is clicked
      var placeholder = event.target.closest('a.json-placeholder');
      if (placeholder && element.contains(placeholder)) {
        event.preventDefault();
        var toggle = siblings(placeholder, 'a.json-toggle')[0];
        if (toggle) toggle.click();
        return;
      }

      // Toggle collapse/expand
      var anchor = event.target.closest('a.json-toggle');
      if (!anchor || !element.contains(anchor)) return;
      event.preventDefault();

      anchor.classList.toggle('collapsed');
      for (var target of siblings(anchor, 'ul.json-dict, ol.json-array')) {
        var visible = target.style.display === 'none';
        target.style.display = visible ? '' : 'none';
        if (visible) {
          for (var ph of siblings(target, '.json-placeholder')) ph.remove();
        } else {
          var count = target.querySelectorAll(':scope > li').length;
          var placeholderText = count + (count > 1 ? ' items' : ' item');
          target.insertAdjacentHTML('afterend', '<a href class="json-placeholder">' + placeholderText + '</a>');
        }
      }
    }, { signal: controller.signal });

    if (options.collapsed == true) {
      // Trigger click to collapse all nodes
      for (var toggle of element.querySelectorAll('a.json-toggle')) {
        toggle.click();
      }
    }
  }

  window.jsonViewer = jsonViewer;
})();
