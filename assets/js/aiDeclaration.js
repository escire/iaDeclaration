/**
 * Copyright 2026 eScire
 * Developed by eScire, with the collaboration of:
 *   - Gustavo Casiano Leon
 *   - Rebeca Maria Sirbu
 * Licensed under the Apache License, Version 2.0 (see LICENSE and NOTICE).
 */
/**
 * aiDeclaration.js
 *
 * Handles interactivity for the AI Declaration form in submission step 3.
 */

(function ($) {
    'use strict';

    // ---- Show/hide sub-form based on radio selection ----

    $('input[name="ai_used"]').on('change', function () {
        var val = $(this).val();
        if (val === '1') {
            $('#aiDeclarationSubForm').show();
            $('#aiDeclarationNoAiMsg').hide();
        } else {
            $('#aiDeclarationSubForm').hide();
            $('#aiDeclarationNoAiMsg').show();
        }
    });

    // Restore state if page reloads with values (e.g. validation error)
    var checkedRadio = $('input[name="ai_used"]:checked');
    if (checkedRadio.length) {
        checkedRadio.trigger('change');
    }

    // ---- Show "other usage type" text field ----

    $('input[name="usage_types[]"][value="other"]').on('change', function () {
        if ($(this).is(':checked')) {
            $('#customUsageTypeWrapper').show();
        } else {
            $('#customUsageTypeWrapper').hide();
        }
    });

    // ---- Show "Otro" content use mode text field ----

    $('input[name="content_use_modes[]"][value="Otro"]').on('change', function () {
        if ($(this).is(':checked')) {
            $('#customContentUseModeWrapper').show();
        } else {
            $('#customContentUseModeWrapper').hide();
        }
    });

    // ---- Show reviewer fields when human review level > 0 ----

    $('#human_review_level').on('change', function () {
        if (parseInt($(this).val(), 10) > 0) {
            $('#humanReviewerFields').show();
        } else {
            $('#humanReviewerFields').hide();
        }
    });

    // ---- Dynamic prompts ----

    var promptIndex = 1; // first row already exists at index 0

    $('#aiDeclarationAddPrompt').on('click', function () {
        var newRow = $('<div class="ai-declaration-prompt-row"></div>');
        var textarea = $('<textarea></textarea>', {
            name: 'prompt_description[]',
            class: 'pkp_form_element ai-declaration-prompt-input',
            rows: 2,
            placeholder: $('#aiDeclarationPromptsList .ai-declaration-prompt-input').first().attr('placeholder')
        });
        var removeBtn = $('<button></button>', {
            type: 'button',
            class: 'pkp_button ai-declaration-remove-prompt',
            title: '✕'
        }).text('✕');

        removeBtn.on('click', function () {
            $(this).closest('.ai-declaration-prompt-row').remove();
            updateRemoveButtons();
        });

        newRow.append(textarea).append(removeBtn);
        $('#aiDeclarationPromptsList').append(newRow);
        promptIndex++;
        updateRemoveButtons();
    });

    function updateRemoveButtons() {
        var rows = $('#aiDeclarationPromptsList .ai-declaration-prompt-row');
        rows.find('.ai-declaration-remove-prompt').toggle(rows.length > 1);
    }

    updateRemoveButtons();

}(jQuery));
