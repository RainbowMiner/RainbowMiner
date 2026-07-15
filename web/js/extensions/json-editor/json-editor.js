/**
 * json-editor (vanilla JS port)
 * Based on jquery.json-editor by yuhui06
 * Ported for RainbowMiner: no jQuery required, same public API:
 *   var editor = new JsonEditor('#json-display', data, options);
 *   editor.load(json); editor.get(); editor.text();
 */
(function() {
    'use strict';

    function encodeJSONStr(str) {
        var encodeMap = {
            '"': '\\"',
            '\\': '\\\\',
            '\b': '\\b',
            '\f': '\\f',
            '\n': '\\n',
            '\r': '\\r',
            '\t': '\\t'
        };

      return str.replace(/["\\\b\f\n\r\t]/g, function (match) {
          return encodeMap[match];
      });
    }

    function encodeJSON(json) {
        if (typeof json === 'string') {
            return encodeJSONStr(json);
        } else if (typeof json === 'object') {
            for (var attr in json) {
                json[attr] = encodeJSON(json[attr]);
            }
        } else if (Array.isArray(json)) {
            for (var i = 0; i < json.length; i++) {
                json[i] = encodeJSON(json[i]);
            }
        }

        return json;
    }

    function JsonEditor(container, json, options) {
        options = options || {};
        if (options.editable !== false) {
            options.editable = true;
        }

        this.container = typeof container === 'string' ? document.querySelector(container) : container;
        this.options = options;

        this.load(json);
    }

    JsonEditor.prototype = {
        constructor: JsonEditor,
        load: function (json) {
            jsonViewer(this.container, encodeJSON(json), {
                collapsed: this.options.defaultCollapsed,
                rootCollapsable: this.options.rootCollapsable,
                withLinks: false,
                withQuotes: true
            });
            this.container.classList.add('json-editor-blackbord');
            this.container.setAttribute('contenteditable', !!this.options.editable);
        },
        get: function () {
            try {
                // expand all collapsed nodes so their placeholders are removed
                for (var toggle of this.container.querySelectorAll('.collapsed')) {
                    toggle.click();
                }
                return JSON.parse(this.container.textContent);
            } catch (ex) {
                throw new Error(ex);
            }
        },
        text: function () {
            try {
                var work = this.container.cloneNode(true);
                for (var placeholder of work.querySelectorAll('.json-placeholder')) {
                    placeholder.remove();
                }
                return work.textContent;
            } catch (ex) {
                throw new Error(ex);
            }
        }
    }

    window.JsonEditor = JsonEditor;
})();
