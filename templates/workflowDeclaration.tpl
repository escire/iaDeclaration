{**
 * Copyright 2026 eScire
 * Developed by eScire, with the collaboration of:
 *   - Gustavo Casiano Leon
 * Licensed under the Apache License, Version 2.0 (see LICENSE and NOTICE).
 *}
{**
 * templates/workflowDeclaration.tpl
 *
 * Tab shown inside the Publication panel of the editorial workflow.
 * Allows managers and editors to view the AI declaration and update its URL.
 *
 * Template variables:
 *   $aiDeclarationWorkflow            array  – Current publication_settings for this publication
 *   $aiDeclarationWorkflowPubId       int    – Current publication ID
 *   $aiDeclarationWorkflowIsPublished bool   – True when publication is STATUS_PUBLISHED
 *   $aiDeclarationComponent           string – Component path for AiDeclarationHandler
 *}

{assign var=wf_used   value=$aiDeclarationWorkflow.aiDeclaration_used|default:""}
{assign var=wf_hash   value=$aiDeclarationWorkflow.aiDeclaration_hash|default:""}
{assign var=wf_url    value=$aiDeclarationWorkflow.aiDeclaration_url|default:""}
{assign var=wf_bypass value=$aiDeclarationWorkflow.aiDeclaration_bypass|default:""}

<tab id="aiDeclaration" label="{translate key="plugins.generic.aiDeclaration.workflow.tab"}">

    <div class="ai-declaration-workflow pkp_form" style="max-width:680px;">

        {if $wf_used !== ""}

            {* ===== DECLARATION EXISTS — status + hash + editable URL ===== *}

            {* Bypass pending notice *}
            {if $wf_bypass === "1"}
            <div style="margin-bottom:1.2em; padding:0.75em 1em; background:#fff3cd; border:1px solid #ffc107; border-radius:4px; color:#856404; font-size:0.9em;">
                &#9888; {translate key="plugins.generic.aiDeclaration.workflow.bypassNotice"}
            </div>
            {/if}

            {* Status badge *}
            <div style="margin-bottom:1.2em;">
                {if $wf_used === "1"}
                    <span style="background:#27ae60; color:#fff; padding:3px 10px; border-radius:3px; font-size:0.85em; display:inline-block;">
                        {translate key="plugins.generic.aiDeclaration.workflow.usedYes"}
                    </span>
                {else}
                    <span style="background:#7f8c8d; color:#fff; padding:3px 10px; border-radius:3px; font-size:0.85em; display:inline-block;">
                        {translate key="plugins.generic.aiDeclaration.workflow.usedNo"}
                    </span>
                {/if}
            </div>

            {* Readonly: Hash *}
            <div class="pkp_form_group" style="margin-bottom:1em;">
                <label class="pkp_form_label">{translate key="plugins.generic.aiDeclaration.workflow.validationHash"}</label>
                <code style="display:block; padding:6px 8px; background:#f5f5f5; border:1px solid #ddd; border-radius:3px; font-size:0.9em; word-break:break-all;">
                    {if $wf_hash}{$wf_hash|escape}{else}&mdash;{/if}
                </code>
            </div>

            {* Editable: URL — always enabled; backend enforces published lock *}
            <div class="pkp_form_group" style="margin-bottom:1.2em;">
                <label class="pkp_form_label" for="aiDeclWorkflowUrl">
                    {translate key="plugins.generic.aiDeclaration.workflow.declarationUrl"}
                </label>
                {if $wf_url}
                    <p style="margin:0 0 4px; font-size:0.85em;">
                        <a href="{$wf_url|escape}" target="_blank" rel="noopener">{$wf_url|escape}</a>
                    </p>
                {/if}
                <input type="text" id="aiDeclWorkflowUrl" class="pkp_form_element"
                    style="width:100%;" value="{$wf_url|escape}"
                    placeholder="https://declarador.usoeticoia.org/..." />
            </div>

            <div style="display:flex; align-items:center; gap:1em;">
                <button type="button" id="aiDeclWorkflowSaveBtn" class="pkp_button">
                    {translate key="plugins.generic.aiDeclaration.workflow.save"}
                </button>
                <span id="aiDeclWorkflowStatus" style="display:none; font-size:0.9em;"></span>
            </div>

        {else}

            {* ===== NO DECLARATION — add form ===== *}
            <p style="color:#666; margin-bottom:1.2em;">
                {translate key="plugins.generic.aiDeclaration.workflow.noDeclaration"}
            </p>

            <div id="aiDeclWorkflowAddForm">
                <h4 style="margin:0 0 0.8em; font-size:1em; font-weight:600;">
                    {translate key="plugins.generic.aiDeclaration.workflow.addDeclarationTitle"}
                </h4>

                {* AI used *}
                <div class="pkp_form_group" style="margin-bottom:1em;">
                    <label class="pkp_form_label">
                        {translate key="plugins.generic.aiDeclaration.form.aiUsed"} <span class="req">*</span>
                    </label>
                    <label style="display:inline-flex; align-items:center; gap:6px; margin-right:1.5em; font-weight:normal;">
                        <input type="radio" name="wf_ai_used_add" value="1" />
                        {translate key="plugins.generic.aiDeclaration.workflow.usedYes"}
                    </label>
                    <label style="display:inline-flex; align-items:center; gap:6px; font-weight:normal;">
                        <input type="radio" name="wf_ai_used_add" value="0" />
                        {translate key="plugins.generic.aiDeclaration.workflow.usedNo"}
                    </label>
                </div>

                {* URL *}
                <div class="pkp_form_group" style="margin-bottom:1em;">
                    <label class="pkp_form_label" for="aiDeclWorkflowAddUrl">
                        {translate key="plugins.generic.aiDeclaration.workflow.declarationUrl"}
                    </label>
                    <input type="text" id="aiDeclWorkflowAddUrl" class="pkp_form_element"
                        style="width:100%;" value=""
                        placeholder="https://declarador.usoeticoia.org/..." />
                </div>

                {* ID (optional — backend fetches hash from API if provided) *}
                <div class="pkp_form_group" style="margin-bottom:1.2em;">
                    <label class="pkp_form_label" for="aiDeclWorkflowAddId">
                        {translate key="plugins.generic.aiDeclaration.workflow.declarationId"}
                        <span style="font-weight:normal; font-size:0.85em;"> ({translate key="plugins.generic.aiDeclaration.common.optional"})</span>
                    </label>
                    <input type="text" id="aiDeclWorkflowAddId" class="pkp_form_element"
                        style="width:100%;" value=""
                        placeholder="AB12CD34" />
                </div>

                <div style="display:flex; align-items:center; gap:1em;">
                    <button type="button" id="aiDeclWorkflowAddBtn" class="pkp_button"
                        data-text-default="{translate key="plugins.generic.aiDeclaration.workflow.save"|escape:"html"}"
                        data-text-saving="{translate key="plugins.generic.aiDeclaration.workflow.saving"|escape:"html"}">
                        {translate key="plugins.generic.aiDeclaration.workflow.save"}
                    </button>
                    <span id="aiDeclWorkflowAddStatus"
                        data-msg-ai-required="{translate key="plugins.generic.aiDeclaration.workflow.aiUsedRequired"|escape:"html"}"
                        data-msg-saved="{translate key="plugins.generic.aiDeclaration.workflow.addSuccess"|escape:"html"}"
                        style="display:none; font-size:0.9em;"></span>
                </div>
            </div>

        {/if}

    </div>{* end .ai-declaration-workflow *}

    <script type="text/javascript">
    (function ($) {ldelim}
        'use strict';

        var updateUrl = '{url router=$smarty.const.ROUTE_COMPONENT component=$aiDeclarationComponent op="manage" verb="ajaxUpdateDeclarationMeta" escape=false}';
        var pubId     = {$aiDeclarationWorkflowPubId|intval};

        // ---- Helper: show status message ----
        function showStatus($el, ok, msg) {ldelim}
            var color = ok ? '#27ae60' : '#c0392b';
            var icon  = ok ? '&#10003;' : '&#10007;';
            $el.html('<span style="color:' + color + ';">' + icon + ' ' + $('<span>').text(msg).html() + '</span>').show();
        {rdelim}

        // ---- Add declaration (no-declaration form) ----
        $(document).on('click', '#aiDeclWorkflowAddBtn', function () {ldelim}
            var $btn    = $(this);
            var $status = $('#aiDeclWorkflowAddStatus');
            var aiUsed  = $('input[name="wf_ai_used_add"]:checked').val();

            if (!aiUsed) {ldelim}
                $status.text($status.attr('data-msg-ai-required')).show();
                return;
            {rdelim}

            $btn.prop('disabled', true).text($btn.data('text-saving') || '…');
            $status.hide().html('');

            $.ajax({ldelim}
                url:  updateUrl,
                type: 'POST',
                data: {ldelim}
                    publicationId:      pubId,
                    aiDeclaration_used: aiUsed,
                    aiDeclaration_url:  $('#aiDeclWorkflowAddUrl').val().trim(),
                    aiDeclaration_id:   $('#aiDeclWorkflowAddId').val().trim(),
                    csrfToken:          pkp.currentUser.csrfToken
                {rdelim},
                success: function (data) {ldelim}
                    if (data && data.status) {ldelim}
                        $status.text($status.attr('data-msg-saved')).show();
                        setTimeout(function () {ldelim} window.location.reload(); {rdelim}, 1500);
                    {rdelim} else {ldelim}
                        var err = (data && data.content && data.content.error) || 'Error';
                        showStatus($status, false, err);
                        $btn.prop('disabled', false).text($btn.data('text-default') || '');
                    {rdelim}
                {rdelim},
                error: function (xhr) {ldelim}
                    showStatus($status, false, 'HTTP ' + xhr.status);
                    $btn.prop('disabled', false).text($btn.data('text-default') || '');
                {rdelim}
            {rdelim});
        {rdelim});

        // ---- Save URL ----
        $(document).on('click', '#aiDeclWorkflowSaveBtn', function () {ldelim}
            var $btn    = $(this);
            var $status = $('#aiDeclWorkflowStatus');

            $btn.prop('disabled', true);
            $status.hide().html('');

            $.ajax({ldelim}
                url:  updateUrl,
                type: 'POST',
                data: {ldelim}
                    publicationId:     pubId,
                    aiDeclaration_url: $('#aiDeclWorkflowUrl').val().trim(),
                    csrfToken:         pkp.currentUser.csrfToken
                {rdelim},
                success: function (data) {ldelim}
                    var ok = data && data.status;
                    showStatus($status, ok, ok
                        ? '{translate key="plugins.generic.aiDeclaration.workflow.saved"|escape:"javascript"}'
                        : ((data && data.content && data.content.error) || 'Error'));
                {rdelim},
                error: function (xhr) {ldelim}
                    showStatus($status, false, 'HTTP ' + xhr.status);
                {rdelim},
                complete: function () {ldelim} $btn.prop('disabled', false); {rdelim}
            {rdelim});
        {rdelim});

    {rdelim}(jQuery));
    </script>

</tab>
