/**
 * Copyright 2026 eScire
 * Developed by eScire, with the collaboration of:
 *   - Gustavo Casiano Leon
 *   - Rebeca Maria Sirbu
 * Licensed under the Apache License, Version 2.0 (see LICENSE and NOTICE).
 */
/**
 * workflowDashboard.js
 *
 * Adds an "AI Declaration" section to the OJS 3.5 editorial workflow using
 * the official pkp.registry API, following the same pattern as the Funding plugin.
 *
 * - pkp.registry.registerComponent  — registers the Vue panel component
 * - pkp.registry.storeExtend        — extends the workflow Pinia store to:
 *     · add a "Declaración IA" item under the Publication menu
 *     · render the AiDeclarationPanel when that item is active
 *
 * Configuration injected inline by PHP (window.aiDeclarationWorkflowConfig):
 *   updateUrl         — AJAX endpoint: ajaxUpdateDeclarationMeta
 *   getMetaUrl        — AJAX endpoint: ajaxGetDeclarationMeta
 *   submissionsApiUrl — (unused here, kept for compatibility)
 *   pluginUrl         — plugin assets base URL
 */
(function (r) {
    'use strict';

    // getCfg() is called lazily so the inline config script can load after this file.
    function getCfg() { return window.aiDeclarationWorkflowConfig || {}; }

    // OJS 3.5 PkpButton primary class string (extracted from build.js PkpButton component).
    // Secondary variant: replace bg-primary/border-transparent/text-on-dark with text-primary/border-light/bg-secondary.
    var BTN_PRI = 'pkpButton inline-flex relative items-center gap-x-1 text-lg-semibold bg-primary border-transparent text-on-dark hover:bg-hover hover:text-on-dark disabled:bg-disabled disabled:text-disabled py-[0.4375rem] px-3 border rounded';

    // -------------------------------------------------------------------------
    // Helpers
    // -------------------------------------------------------------------------
    function getCsrf() {
        try { return pkp.currentUser.csrfToken || ''; } catch (e) { return ''; }
    }

    // -------------------------------------------------------------------------
    // AiDeclarationPanel — Vue 3 component rendered inside the workflow panel
    // -------------------------------------------------------------------------
    var AiDeclarationPanel = {
        props: {
            submissionId:  { type: String, required: true },
            publicationId: { type: String, required: true },
        },
        setup: function (props) {
            var loading   = r.ref(true);
            var saving    = r.ref(false);
            var decl      = r.ref(null);   // null = no declaration, object = has data
            var urlInput  = r.ref('');
            var usedInput = r.ref('');
            var addUrl    = r.ref('');
            var addId     = r.ref('');
            var statusMsg = r.ref('');
            var statusOk  = r.ref(true);

            function loadMeta() {
                loading.value = true;
                statusMsg.value = '';
                jQuery.ajax({
                    url:  getCfg().getMetaUrl,
                    type: 'POST',
                    data: { publicationId: props.publicationId, csrfToken: getCsrf() },
                    success: function (resp) {
                        var s = (resp && resp.status && resp.content && resp.content.settings)
                            ? resp.content.settings : {};
                        if (s.aiDeclaration_used !== undefined && s.aiDeclaration_used !== '') {
                            decl.value     = s;
                            urlInput.value = s.aiDeclaration_url || '';
                        } else {
                            decl.value = null;
                        }
                        loading.value = false;
                    },
                    error: function () { loading.value = false; }
                });
            }

            r.onMounted(loadMeta);

            function saveUrl() {
                saving.value  = true;
                statusMsg.value = '';
                jQuery.ajax({
                    url:  getCfg().updateUrl,
                    type: 'POST',
                    data: { publicationId: props.publicationId, aiDeclaration_url: urlInput.value, csrfToken: getCsrf() },
                    success: function (resp) {
                        saving.value  = false;
                        statusOk.value  = !!(resp && resp.status);
                        statusMsg.value = statusOk.value
                            ? '\u2713 Guardado'
                            : ((resp && resp.content && resp.content.error) || 'Error');
                    },
                    error: function (xhr) {
                        saving.value  = false;
                        statusOk.value  = false;
                        statusMsg.value = 'HTTP ' + xhr.status;
                    }
                });
            }

            function addDecl() {
                if (!usedInput.value) {
                    statusOk.value  = false;
                    statusMsg.value = 'Selecciona si se us\u00f3 IA.';
                    return;
                }
                saving.value  = true;
                statusMsg.value = '';
                jQuery.ajax({
                    url:  getCfg().updateUrl,
                    type: 'POST',
                    data: {
                        publicationId:      props.publicationId,
                        aiDeclaration_used: usedInput.value,
                        aiDeclaration_url:  addUrl.value,
                        aiDeclaration_id:   addId.value,
                        csrfToken:          getCsrf(),
                    },
                    success: function (resp) {
                        saving.value = false;
                        if (resp && resp.status) {
                            statusOk.value  = true;
                            statusMsg.value = '\u2713 Guardado';
                            loadMeta();   // re-fetch to switch to edit view
                        } else {
                            statusOk.value  = false;
                            statusMsg.value = (resp && resp.content && resp.content.error) || 'Error';
                        }
                    },
                    error: function (xhr) {
                        saving.value  = false;
                        statusOk.value  = false;
                        statusMsg.value = 'HTTP ' + xhr.status;
                    }
                });
            }

            // -----------------------------------------------------------------
            // Render function (no template compiler available at runtime)
            // -----------------------------------------------------------------
            return function () {
                var h = r.h;
                var nodes = [];

                if (loading.value) {
                    nodes.push(h('p', { style: 'color:#6b7280;font-size:.85em;' }, 'Cargando\u2026'));

                } else if (decl.value !== null) {
                    // ── Existing declaration ─────────────────────────────────
                    var s    = decl.value;
                    var used = String(s.aiDeclaration_used || '');
                    var hash = s.aiDeclaration_hash || '';

                    if (s.aiDeclaration_bypass === '1') {
                        nodes.push(h('p', {
                            style: 'margin:0 0 .75rem;padding:.4rem .7rem;background:#fff3cd;border:1px solid #ffc107;border-radius:4px;color:#856404;font-size:.82em;',
                        }, '\u26a0 El autor activ\u00f3 el bypass \u2014 declaraci\u00f3n pendiente de registro.'));
                    }

                    nodes.push(h('div', { style: 'margin-bottom:.75rem;' }, [
                        h('span', {
                            style: 'background:' + (used === '1' ? '#27ae60' : '#6b7280')
                                + ';color:#fff;padding:2px 10px;border-radius:3px;font-size:.8em;font-weight:600;',
                        }, used === '1' ? 'IA utilizada' : 'Sin IA'),
                    ]));

                    if (hash) {
                        nodes.push(h('div', { style: 'margin-bottom:.75rem;' }, [
                            h('label', { style: 'font-size:.8em;font-weight:600;display:block;margin-bottom:.2rem;' }, 'Hash'),
                            h('code', { style: 'font-size:.76em;word-break:break-all;background:#f5f5f5;padding:.2rem .4rem;border:1px solid #ddd;border-radius:3px;display:block;' }, hash),
                        ]));
                    }

                    nodes.push(h('div', { style: 'margin-bottom:.75rem;' }, [
                        h('label', { style: 'font-size:.8em;font-weight:600;display:block;margin-bottom:.2rem;' }, 'URL de declaraci\u00f3n'),
                        h('input', {
                            type:        'text',
                            value:       urlInput.value,
                            placeholder: 'https://\u2026',
                            style:       'width:100%;box-sizing:border-box;border:1px solid #ced4da;border-radius:4px;padding:.35rem .5rem;font-size:.875em;',
                            onInput:     function (e) { urlInput.value = e.target.value; },
                        }),
                    ]));

                    nodes.push(h('div', { style: 'display:flex;align-items:center;gap:.6rem;' }, [
                        h('button', {
                            type:     'button',
                            class:    BTN_PRI,
                            disabled: saving.value,
                            style:    'font-size:.8em;',
                            onClick:  saveUrl,
                        }, saving.value ? 'Guardando\u2026' : 'Guardar URL'),
                        statusMsg.value
                            ? h('span', { style: 'font-size:.82em;color:' + (statusOk.value ? '#27ae60' : '#dc2626') + ';' }, statusMsg.value)
                            : null,
                    ]));

                } else {
                    // ── No declaration yet ───────────────────────────────────
                    nodes.push(h('p', { style: 'color:#6b7280;font-size:.84em;margin:0 0 .75rem;' }, 'No hay declaraci\u00f3n registrada para esta publicaci\u00f3n.'));

                    var pubId = props.publicationId;
                    nodes.push(h('div', { style: 'margin-bottom:.6rem;' }, [
                        h('label', { style: 'font-size:.8em;font-weight:600;display:block;margin-bottom:.25rem;' }, [
                            'IA utilizada\u00a0', h('span', { style: 'color:#dc2626;' }, '*'),
                        ]),
                        h('label', { style: 'display:inline-flex;align-items:center;gap:.3rem;margin-right:1rem;font-size:.875em;cursor:pointer;' }, [
                            h('input', { type: 'radio', name: 'aiDeclUsed_' + pubId, value: '1', onChange: function (e) { usedInput.value = e.target.value; } }),
                            'S\u00ed',
                        ]),
                        h('label', { style: 'display:inline-flex;align-items:center;gap:.3rem;font-size:.875em;cursor:pointer;' }, [
                            h('input', { type: 'radio', name: 'aiDeclUsed_' + pubId, value: '0', onChange: function (e) { usedInput.value = e.target.value; } }),
                            'No',
                        ]),
                    ]));

                    nodes.push(h('div', { style: 'margin-bottom:.6rem;' }, [
                        h('label', { style: 'font-size:.8em;font-weight:600;display:block;margin-bottom:.2rem;' }, 'URL de declaraci\u00f3n'),
                        h('input', {
                            type:        'text',
                            value:       addUrl.value,
                            placeholder: 'https://declarador.usoeticoia.org/\u2026',
                            style:       'width:100%;box-sizing:border-box;border:1px solid #ced4da;border-radius:4px;padding:.35rem .5rem;font-size:.875em;',
                            onInput:     function (e) { addUrl.value = e.target.value; },
                        }),
                    ]));

                    nodes.push(h('div', { style: 'margin-bottom:.75rem;' }, [
                        h('label', { style: 'font-size:.8em;font-weight:600;display:block;margin-bottom:.2rem;' }, [
                            'ID de declaraci\u00f3n\u00a0', h('span', { style: 'font-weight:400;' }, '(opc.)'),
                        ]),
                        h('input', {
                            type:        'text',
                            value:       addId.value,
                            placeholder: 'AB12CD34',
                            style:       'width:100%;box-sizing:border-box;border:1px solid #ced4da;border-radius:4px;padding:.35rem .5rem;font-size:.875em;',
                            onInput:     function (e) { addId.value = e.target.value; },
                        }),
                    ]));

                    nodes.push(h('div', { style: 'display:flex;align-items:center;gap:.6rem;' }, [
                        h('button', {
                            type:     'button',
                            class:    BTN_PRI,
                            disabled: saving.value,
                            style:    'font-size:.8em;',
                            onClick:  addDecl,
                        }, saving.value ? 'Guardando\u2026' : 'Guardar declaraci\u00f3n'),
                        statusMsg.value
                            ? h('span', { style: 'font-size:.82em;color:' + (statusOk.value ? '#27ae60' : '#dc2626') + ';' }, statusMsg.value)
                            : null,
                    ]));
                }

                return h('div', { style: 'padding:1.5rem;' }, [
                    h('h3', { style: 'font-size:.9em;font-weight:600;margin:0 0 1rem;padding-bottom:.5rem;border-bottom:1px solid #e5e7eb;' },
                        'Declaraci\u00f3n de uso de IA'),
                ].concat(nodes));
            };
        },
    };

    // -------------------------------------------------------------------------
    // Register component + extend workflow store
    // -------------------------------------------------------------------------
    pkp.registry.registerComponent('AiDeclarationPanel', AiDeclarationPanel);

    pkp.registry.storeExtend('workflow', function (o) {
        var u = o.store;

        // Add menu item under Publication
        u.extender.extendFn('getMenuItems', function (items) {
            return items.map(function (n) {
                if (n.key !== 'publication') { return n; }
                return Object.assign({}, n, {
                    items: n.items.concat([{
                        key:   'publication_aiDeclaration',
                        label: 'Declaraci\u00f3n IA',
                        state: {
                            primaryMenuItem:   'publication',
                            secondaryMenuItem: 'aiDeclaration',
                            title:             'Declaraci\u00f3n de uso de IA',
                        },
                    }]),
                });
            });
        });

        // Render panel when the item is active
        u.extender.extendFn('getPrimaryItems', function (items, e) {
            var sel = e && e.selectedMenuState;
            if (!sel
                || sel.primaryMenuItem   !== 'publication'
                || sel.secondaryMenuItem !== 'aiDeclaration') {
                return items;
            }
            var sub   = e && e.submission;
            var subId = sub && sub.id   ? String(sub.id)                   : '';
            var pubId = sub && sub.currentPublicationId
                ? String(sub.currentPublicationId) : '';
            return [{
                component: 'AiDeclarationPanel',
                props: { submissionId: subId, publicationId: pubId },
            }];
        });
    });

}(pkp.modules.vue));
