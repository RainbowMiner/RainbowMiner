// RainbowMiner setup form renderer v1.0 (Phase 5)
// Renders the setup form from /data/setupschema.json - adding a new config
// option means adding one JSON entry instead of hand-writing form markup.
//
// The schema was extracted losslessly from the previous hand-written
// setup.html and verified field-by-field against it. Item kinds:
//   field      - one control (input of any type / select / range) in a row
//   inputgroup - ordered controls + unit addons inside an .input-group
//   dynamic    - placeholder div filled at runtime (pools/devices lists)
//   group      - wrapper div carrying visibility classes (is--client, ...)
//   raw        - verbatim HTML passthrough
//
// All ids and names are preserved, so the page logic (loadconfig population,
// bindToggle visibility, submit) works unchanged on the rendered form.

"use strict";

const RbmSetup = (function () {

    function attrString(attrs) {
        let out = "";
        for (const [key, value] of Object.entries(attrs || {})) {
            out += " " + key + '="' + esc(value) + '"';
        }
        return out;
    }

    function controlHtml(item) {
        const idname = ' id="' + esc(item.id) + '" name="' + esc(item.key) + '"';
        switch (item.control) {
            case "select": {
                let opts = "";
                for (const o of item.options || []) {
                    opts += '<option value="' + esc(o.value) + '"' + (o.selected ? " selected" : "") + ">" + o.label + "</option>";
                }
                return '<select class="form-select"' + idname + attrString(item.attrs) + ">" + opts + "</select>";
            }
            case "range":
                return '<input type="range" class="form-range"' + idname + attrString(item.attrs) + ">";
            default:
                // control carries the literal input type (text, number,
                // password, email, url, ...) as extracted from the markup
                return '<input type="' + esc(item.control) + '" class="form-control"' + idname + attrString(item.attrs) + ">";
        }
    }

    function helpHtml(help) {
        if (!help) return "";
        return '<div class="form-text"' + (help.id ? ' id="' + esc(help.id) + '"' : "") + ">" + help.html + "</div>";
    }

    function labelHtml(item) {
        const cls = (item.label && item.label.class) || "col-sm-2 col-form-label";
        const forId = item.id || (item.label && item.label.for);
        return "<label" + (forId ? ' for="' + esc(forId) + '"' : "") + ' class="' + esc(cls) + '">' + item.label.html + "</label>";
    }

    function rowOpen(item) {
        const classes = ["mb-3", "row"].concat(item.rowClasses || []);
        return '<div class="' + esc(classes.join(" ")) + '">';
    }

    function renderItem(item) {
        switch (item.kind) {
            case "field": {
                if (item.control === "range") {
                    return rowOpen(item) + labelHtml(item) +
                        '<div class="' + esc(item.colClass) + '">' + controlHtml(item) + "</div>" +
                        '<div class="' + esc(item.spanColClass) + '"' + (item.spanColStyle ? ' style="' + esc(item.spanColStyle) + '"' : "") + ">" +
                        '<span class="input-group-text" id="' + esc(item.valueSpan.id) + '">' + esc(item.valueSpan.text) + "</span>" +
                        "</div></div>";
                }
                return rowOpen(item) + labelHtml(item) +
                    '<div class="' + esc(item.colClass) + '">' + controlHtml(item) + helpHtml(item.help) + "</div></div>";
            }
            case "inputgroup": {
                let parts = "";
                for (const p of item.parts) {
                    if (p.part === "input") {
                        parts += controlHtml({ control: p.control, id: p.id, key: p.key, attrs: p.attrs });
                    } else {
                        parts += '<span class="input-group-text"' + (p.id ? ' id="' + esc(p.id) + '"' : "") + ">" + p.html + "</span>";
                    }
                }
                return rowOpen(item) + labelHtml(item) +
                    '<div class="' + esc(item.colClass) + '"><div class="input-group">' + parts + "</div>" + helpHtml(item.help) + "</div></div>";
            }
            case "dynamic": {
                return rowOpen(item) + (item.label ? labelHtml(item) : "") +
                    '<div class="' + esc(item.colClass) + '" id="' + esc(item.target) + '"></div></div>';
            }
            case "group": {
                return '<div class="' + esc(item.classes.join(" ")) + '">' + item.items.map(renderItem).join("") + "</div>";
            }
            case "raw":
                return item.html;
            default:
                console.error("rbm-setup: unknown item kind", item);
                return "";
        }
    }

    function renderSection(section, accordionId) {
        return '<div class="accordion-item">' +
            '<h2 class="accordion-header" id="' + esc(section.headingId) + '">' +
            '<button class="accordion-button' + (section.expanded ? "" : " collapsed") + '" type="button" data-bs-toggle="collapse" data-bs-target="#' + esc(section.collapseId) + '" aria-expanded="' + (section.expanded ? "true" : "false") + '" aria-controls="' + esc(section.collapseId) + '">' +
            esc(section.title) +
            "</button></h2>" +
            '<div id="' + esc(section.collapseId) + '" class="accordion-collapse collapse' + (section.expanded ? " show" : "") + '" aria-labelledby="' + esc(section.headingId) + '" data-bs-parent="#' + esc(accordionId) + '">' +
            '<div class="accordion-body">' + section.items.map(renderItem).join("") + "</div></div></div>";
    }

    // Render the whole form content into the <form> element
    function render(form, schema) {
        let html = "";
        for (const h of schema.form.hidden || []) {
            html += '<input type="hidden" name="' + esc(h.name) + '" value="' + esc(h.value) + '" />';
        }
        html += '<div class="accordion" id="' + esc(schema.form.accordionId) + '">';
        html += schema.sections.map((s) => renderSection(s, schema.form.accordionId)).join("");
        if (schema.submit) html += schema.submit.html;
        html += "</div>";
        form.innerHTML = html;
    }

    return { render: render, renderItem: renderItem };
})();
