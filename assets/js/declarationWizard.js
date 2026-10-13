/**
 * Copyright 2026 eScire
 * Developed by eScire, with the collaboration of:
 *   - Gustavo Casiano Leon
 *   - Rebeca Maria Sirbu
 * Licensed under the Apache License, Version 2.0 (see LICENSE and NOTICE).
 */
/**
 * declarationWizard.js
 *
 * Handles all interactivity for the AI Declaration form injected into the
 * OJS 3.4 submission wizard review step.
 *
 * This file is loaded via addJavaScript() from TemplateManager::display so it
 * is available in <head> before Vue mounts. All handlers use event delegation
 * on `document` so they work regardless of when the form appears in the DOM.
 *
 * Configuration is read from data-* attributes on #aiDeclarationSection:
 *   data-create-url    — AJAX endpoint for creating a declaration
 *   data-find-url      — AJAX endpoint for finding an existing declaration
 *   data-submission-id — Current submission ID
 *   data-required      — "1" if declaration is mandatory, "0" otherwise
 *   data-existing-id   — Previously saved declaration ID (if any)
 *   data-existing-hash — Previously saved validation hash (if any)
 *   data-existing-url  — Previously saved declaration URL (if any)
 */
(function ($) {
    'use strict';

    // ---- Session state ----
    var _confirmedId   = '';
    var _confirmedHash = '';
    var _confirmedUrl  = '';
    var _bypassed      = false;
    var _initialized   = false;
    var _apiFailCount  = 0;

    // ---- Helpers ----
    function getSection() {
        return $('#aiDeclarationSection');
    }

    function getConfig() {
        var $s = getSection();
        return {
            createUrl:    $s.data('create-url')    || '',
            findUrl:      $s.data('find-url')      || '',
            submissionId: $s.data('submission-id') || 0,
            required:     $s.data('required') == '1',
        };
    }

    // ---- Panel visibility ----
    function updatePanels(val) {
        $('#aiDeclarationSubForm').toggle(val === '1');
        $('#aiDeclarationNoAiMsg').toggle(val === '0');
        $('#aiDeclarationExistingForm').toggle(val === 'existing');
    }

    // ---- Confirmed badge ----
    function showBadge(id, url, hash) {
        var label = id || '\u2014';
        var html  = url
            ? '<a href="' + $('<span>').text(url).html() + '" target="_blank" rel="noopener">' + $('<span>').text(label).html() + '</a>'
            : $('<span>').text(label).html();
        if (hash) {
            html += ' &nbsp;<code style="font-size:0.82em;color:#555;">' + $('<span>').text(hash).html() + '</code>';
        }
        $('#aiDeclarationConfirmedText').html(html);
        $('#aiDeclarationConfirmedBadge').show();
    }

    function storeConfirmed(id, hash, url) {
        _confirmedId   = id   || '';
        _confirmedHash = hash || '';
        _confirmedUrl  = url  || '';
        _bypassed      = false;
        showBadge(_confirmedId, _confirmedUrl, _confirmedHash);
    }

    function clearConfirmed() {
        _confirmedId = _confirmedHash = _confirmedUrl = '';
        _bypassed    = false;
        $('#aiDeclarationConfirmedBadge').hide();
        $('#aiDeclarationConfirmedText').html('');
        $('.ai-declaration-status').hide().html('');
    }

    // ---- API failure counter ----
    function onApiFailure() {
        if (++_apiFailCount >= 3) {
            $('#aiDeclBypassSection').show();
        }
    }

    // ---- Generic AJAX helper ----
    function doAjax(url, formData, statusDiv, btn) {
        btn.prop('disabled', true).text(btn.data('text-loading') || '…');
        if (statusDiv) statusDiv.hide().html('');

        $.ajax({
            url:  url,
            type: 'POST',
            data: formData,
            success: function (data) {
                var content = data.content || {};
                if (data.status && content.success) {
                    _apiFailCount = 0;
                    storeConfirmed(
                        content.declaration_id  || '',
                        content.validation_hash || '',
                        content.declaration_url || ''
                    );
                    if (statusDiv) {
                        var msg = content.declaration_id
                            ? '&#10003; ' + $('<span>').text(content.declaration_id).html()
                            : '&#10003; OK';
                        statusDiv.html('<span class="ai-decl-ok">' + msg + '</span>').show();
                    }
                } else {
                    onApiFailure();
                    var errMsg = (content && content.error) ? content.error : 'Error desconocido';
                    if (statusDiv) {
                        statusDiv.html('<span class="ai-decl-err">&#10007; ' + $('<span>').text(errMsg).html() + '</span>').show();
                    }
                }
            },
            error: function (xhr) {
                onApiFailure();
                if (statusDiv) {
                    statusDiv.html('<span class="ai-decl-err">&#10007; Error HTTP ' + xhr.status + '</span>').show();
                }
            },
            complete: function () {
                btn.prop('disabled', false).text(btn.data('text-default') || btn.text());
            }
        });
    }

    // ---- Initialization (runs once when #aiDeclarationSection appears) ----
    function initSection() {
        var $s = getSection();

        // Restore confirmed state from data attributes (pre-existing declaration)
        _confirmedId   = $s.data('existing-id')   || '';
        _confirmedHash = $s.data('existing-hash')  || '';
        _confirmedUrl  = $s.data('existing-url')   || '';

        if (_confirmedId) {
            showBadge(_confirmedId, _confirmedUrl, _confirmedHash);
        }

        // Restore panel visibility for a pre-checked radio (returning to wizard)
        var $checked = $('input[name="ai_used"]:checked');
        if ($checked.length) {
            updatePanels($checked.val());
        }

        updateRemoveButtons();
    }

    // ---- Vue integration ----
    // injectDeclarationForm(vm) is called from root:mounted when the aiDeclaration
    // step becomes active. The form HTML is pre-rendered server-side and stored in
    // window.aiDeclarationFormHTML by the PHP hook.
    var _formInjected = false;

    // The PKP <step> component declares `id` as a Vue prop, so Vue does NOT apply
    // it as an HTML attribute — the root element is <div class="pkpStep"> with NO id.
    // We must traverse the Vue component tree to locate the right step element.
    function findStepElement(vm) {
        var found = null;
        function walk(comp) {
            if (found) { return; }
            if (comp.$options && comp.$options._componentTag === 'step' && comp.id === 'aiDeclaration') {
                found = comp.$el;
                return;
            }
            (comp.$children || []).forEach(walk);
        }
        walk(vm);
        return found;
    }

    function injectDeclarationForm(vm) {
        if (_formInjected || document.getElementById('aiDeclarationSection')) {
            return;
        }
        var html = (typeof window.aiDeclarationFormHTML === 'string') ? window.aiDeclarationFormHTML : '';
        if (!html) { return; }

        var stepEl = findStepElement(vm);
        if (!stepEl) { return; }

        // Find the panel container (empty since sections:[]) or fall back to the step element
        var panel  = stepEl.querySelector('.pkpPanel');
        var target = panel || stepEl;
        target.insertAdjacentHTML('beforeend', html);

        _formInjected = true;
        if (!_initialized) {
            _initialized = true;
            initSection();
        }
    }

    // =========================================================================
    // Event handlers — all delegated on document so they work with dynamic DOM
    // =========================================================================

    // Radio button change → show/hide panels
    $(document).on('change', 'input[name="ai_used"]', function () {
        updatePanels($(this).val());
        $('#aiDeclClientError').hide();
    });

    // Clear confirmed badge
    $(document).on('click', '#aiDeclarationClearBtn', clearConfirmed);

    // Create declaration (AI used)
    $(document).on('click', '#aiDeclarationCreateBtn', function () {
        var $btn     = $(this);
        var cfg      = getConfig();
        var hasType  = $('input[name="usage_types[]"]:checked').length > 0;
        var toolName = $('#ai_tool_name').val().trim();
        var month    = $('#ai_tool_date_month').val();
        var year     = $('#ai_tool_date_year').val();
        var purpose  = $('#specific_purpose').val().trim();
        var hasPrompt = false;

        $('textarea[name="prompt_description[]"]').each(function () {
            if ($(this).val().trim()) hasPrompt = true;
        });

        var $status = $('#aiDeclarationCreateStatus');
        if (!hasType || !toolName || !month || !year || !purpose || !hasPrompt) {
            $status.html('<span class="ai-decl-err">&#10007; Complete todos los campos marcados con * antes de crear la declaración.</span>').show();
            return;
        }

        if (_confirmedId) {
            if (!confirm('Ya existe una declaración registrada (ID: ' + _confirmedId + ').\n\n¿Deseas crear una nueva?')) {
                return;
            }
        }

        var formData = $('#aiDeclarationSubForm').find('input:not([type=button]), select, textarea').serialize();
        formData += '&ai_used=1&submissionId=' + encodeURIComponent(cfg.submissionId)
                 + '&csrfToken=' + encodeURIComponent(pkp.currentUser.csrfToken);

        doAjax(cfg.createUrl, formData, $status, $btn);
    });

    // Register no-AI declaration
    $(document).on('click', '#aiDeclarationNoAiBtn', function () {
        var cfg = getConfig();

        if (_confirmedId) {
            if (!confirm('Ya existe una declaración registrada (ID: ' + _confirmedId + ').\n\n¿Deseas registrar una nueva declaración sin IA?')) {
                return;
            }
        }

        var formData = 'ai_used=0&submissionId=' + encodeURIComponent(cfg.submissionId)
                     + '&csrfToken=' + encodeURIComponent(pkp.currentUser.csrfToken);
        doAjax(cfg.createUrl, formData, $('#aiDeclarationNoAiStatus'), $(this));
    });

    // Find existing declaration
    $(document).on('click', '#aiDeclarationFindBtn', function () {
        var cfg        = getConfig();
        var identifier = $('#existing_declaration_id').val().trim();
        var $status    = $('#aiDeclarationExistingStatus');

        if (!identifier) {
            $status.html('<span class="ai-decl-err">&#10007; Introduce el ID o hash de tu declaración.</span>').show();
            return;
        }

        var formData = 'existing_declaration_id=' + encodeURIComponent(identifier)
                     + '&submissionId=' + encodeURIComponent(cfg.submissionId)
                     + '&csrfToken=' + encodeURIComponent(pkp.currentUser.csrfToken);
        doAjax(cfg.findUrl, formData, $status, $(this));
    });

    // Field toggles
    $(document).on('change', 'input[name="usage_types[]"][value="other"]', function () {
        $('#customUsageTypeWrapper').toggle($(this).is(':checked'));
    });

    $(document).on('change', 'input[name="content_use_modes[]"][value="5"]', function () {
        $('#customContentUseModeWrapper').toggle($(this).is(':checked'));
    });

    $(document).on('change', '#human_review_level', function () {
        $('#humanReviewerFields').toggle(parseInt($(this).val(), 10) > 0);
    });

    // Dynamic prompts
    $(document).on('click', '#aiDeclarationAddPrompt', function () {
        var placeholder = $('#aiDeclarationPromptsList .ai-declaration-prompt-input').first().attr('placeholder') || '';
        var $row = $('<div class="ai-declaration-prompt-row"></div>');
        var $ta  = $('<textarea></textarea>')
                    .attr({ name: 'prompt_description[]', rows: 2, placeholder: placeholder })
                    .addClass('pkp_form_element ai-declaration-prompt-input');
        var $rm  = $('<button type="button">&#x2715;</button>').addClass('pkp_button ai-declaration-remove-prompt');
        $('#aiDeclarationPromptsList').append($row.append($ta).append($rm));
        updateRemoveButtons();
    });

    $(document).on('click', '.ai-declaration-remove-prompt', function () {
        $(this).closest('.ai-declaration-prompt-row').remove();
        updateRemoveButtons();
    });

    function updateRemoveButtons() {
        var $rows = $('#aiDeclarationPromptsList .ai-declaration-prompt-row');
        $rows.find('.ai-declaration-remove-prompt').toggle($rows.length > 1);
    }

    // Bypass button
    $(document).on('click', '#aiDeclBypassBtn', function () {
        var pendingText = $(this).data('pending-text') || 'Pendiente';
        _bypassed = true;
        $('#aiDeclarationConfirmedText').html(
            '<em style="color:#856404;">' + $('<span>').text(pendingText).html() + '</em>'
        );
        $('#aiDeclarationConfirmedBadge').show();
        $('#aiDeclBypassSection').hide();
        $('#aiDeclClientError').hide();
    });

    // =========================================================================
    // OJS 3.4 Vue integration: hook into root:mounted to inject form + validate
    // =========================================================================

    // pkp.eventBus is available in <head> because build.js (STYLE_SEQUENCE_CORE)
    // loads before our script (STYLE_SEQUENCE_LATE).
    if (window.pkp && pkp.eventBus) {
        pkp.eventBus.$on('root:mounted', function (id, vm) {

            // Inject the form when the aiDeclaration step becomes active.
            // { immediate: true } handles the case where the wizard opens on this step.
            vm.$watch(
                function () { return vm.currentStep; },
                function (step) {
                    if (step && step.id === 'aiDeclaration') {
                        vm.$nextTick(function () { injectDeclarationForm(vm); });
                    }
                },
                { immediate: true }
            );

            // Override vm.nextStep to validate before leaving the aiDeclaration step.
            var _originalNextStep = vm.nextStep.bind(vm);
            vm.nextStep = function () {
                if (vm.currentStep && vm.currentStep.id === 'aiDeclaration') {
                    var aiUsed = $('input[name="ai_used"]:checked').val() || '';
                    var $err   = $('#aiDeclClientError');
                    $err.hide();

                    // If required, a radio button must be selected
                    if (window.aiDeclarationRequired && !aiUsed) {
                        $err.text($err.attr('data-msg-required') || 'La declaración es obligatoria.').show();
                        var s = document.getElementById('aiDeclarationSection');
                        if (s) { s.scrollIntoView({ behavior: 'smooth', block: 'center' }); }
                        return;
                    }

                    // If AI was used, a declaration must be confirmed (or bypassed)
                    if (aiUsed && !_confirmedId && !_bypassed) {
                        $err.text($err.attr('data-msg-unconfirmed') || 'Debes registrar o vincular una declaración.').show();
                        var s = document.getElementById('aiDeclarationSection');
                        if (s) { s.scrollIntoView({ behavior: 'smooth', block: 'center' }); }
                        return;
                    }
                }
                _originalNextStep();
            };
        });
    }

}(jQuery));
