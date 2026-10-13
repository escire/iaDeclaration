{**
 * Copyright 2026 eScire
 * Developed by eScire, with the collaboration of:
 *   - Gustavo Casiano Leon
 * Licensed under the Apache License, Version 2.0 (see LICENSE and NOTICE).
 *}
{**
 * templates/submissionStep3.tpl
 *
 * AI Declaration form injected at submission step 3 via the hook
 * Templates::Submission::SubmissionMetadataForm::AdditionalMetadata.
 *
 * Flow:
 *   1. Author selects an option (Yes AI / No AI / Existing declaration).
 *   2. Fills the relevant fields.
 *   3. Clicks the action button → AJAX call → inline confirmation badge.
 *   4. Clicks "Save and continue" → execute hook saves the confirmed IDs.
 *
 * Template variables assigned from PHP:
 *   $aiDeclarationRequired     bool   – Declaration is mandatory
 *   $aiDeclarationYears        array  – Range of selectable years
 *   $aiDeclarationPluginUrl    string – Plugin assets base URL
 *   $aiDeclarationCreateUrl    string – AJAX URL for creating a declaration
 *   $aiDeclarationFindUrl      string – AJAX URL for finding a declaration
 *   $aiDeclarationSubmissionId int    – Current submission ID
 *   $aiDeclarationExisting     array  – Previously saved settings (if any)
 *}

<link rel="stylesheet" href="{$aiDeclarationPluginUrl}/assets/css/aiDeclaration.css" />

{* Pre-populate confirmed hidden fields from previously saved settings *}
{assign var=aiDeclExistingId   value=$aiDeclarationExisting.aiDeclaration_id|default:""}
{assign var=aiDeclExistingHash value=$aiDeclarationExisting.aiDeclaration_hash|default:""}
{assign var=aiDeclExistingUrl  value=$aiDeclarationExisting.aiDeclaration_url|default:""}
{assign var=aiDeclExistingUsed value=$aiDeclarationExisting.aiDeclaration_used|default:""}

{* These hidden fields are submitted with the step 3 form *}
<input type="hidden" name="aiDeclaration_confirmed_id"   id="aiDeclaration_confirmed_id"   value="{$aiDeclExistingId|escape}" />
<input type="hidden" name="aiDeclaration_confirmed_hash" id="aiDeclaration_confirmed_hash" value="{$aiDeclExistingHash|escape}" />
<input type="hidden" name="aiDeclaration_confirmed_url"  id="aiDeclaration_confirmed_url"  value="{$aiDeclExistingUrl|escape}" />
<input type="hidden" name="aiDeclaration_bypass"         id="aiDeclaration_bypass"         value="" />

<div class="pkp_form_section ai-declaration-section" id="aiDeclarationSection">

    <h3 class="ai-declaration-title">
        {translate key="plugins.generic.aiDeclaration.form.title"}
    </h3>
    <p class="ai-declaration-intro">
        {translate key="plugins.generic.aiDeclaration.form.intro"}
        {if $aiDeclarationRequired}<span class="req">*</span>{/if}
    </p>

    {* ---- Option selector ---- *}
    <div class="ai-declaration-options">
        <label class="ai-declaration-radio-label">
            <input type="radio" name="ai_used" id="ai_used_yes" value="1"
                {if $aiDeclExistingUsed === "1" && $aiDeclExistingId !== ""}checked="checked"{/if} />
            {translate key="plugins.generic.aiDeclaration.form.aiUsedYes"}
        </label>
        <label class="ai-declaration-radio-label">
            <input type="radio" name="ai_used" id="ai_used_no" value="0"
                {if $aiDeclExistingUsed === "0" && $aiDeclExistingId !== ""}checked="checked"{/if} />
            {translate key="plugins.generic.aiDeclaration.form.aiUsedNo"}
        </label>
        <label class="ai-declaration-radio-label">
            <input type="radio" name="ai_used" id="ai_used_existing" value="existing" />
            {translate key="plugins.generic.aiDeclaration.form.aiUsedExisting"}
        </label>
    </div>

    {* ---- No-AI panel ---- *}
    <div id="aiDeclarationNoAiMsg" class="ai-declaration-noai-msg" style="display:none;">
        <p>{translate key="plugins.generic.aiDeclaration.form.noAiConfirm"}</p>
        <button type="button" id="aiDeclarationNoAiBtn" class="pkp_button"
            data-text-default="{translate key="plugins.generic.aiDeclaration.form.action.registerNoAi"}"
            data-text-loading="{translate key="plugins.generic.aiDeclaration.form.action.registering"}">
            {translate key="plugins.generic.aiDeclaration.form.action.registerNoAi"}
        </button>
        <div id="aiDeclarationNoAiStatus" class="ai-declaration-status" style="display:none;"></div>
    </div>

    {* ---- Existing declaration panel ---- *}
    <div id="aiDeclarationExistingForm" style="display:none;">
        <div class="ai-declaration-field">
            <label class="pkp_form_label" for="existing_declaration_id">
                {translate key="plugins.generic.aiDeclaration.form.existingDeclarationId"} <span class="req">*</span>
            </label>
            <p class="ai-declaration-intro" style="margin-top:0;">
                {translate key="plugins.generic.aiDeclaration.form.existingDeclarationId.hint"}
            </p>
            <div style="display:flex; gap:0.75em; align-items:flex-start; flex-wrap:wrap;">
                <input type="text" name="existing_declaration_id" id="existing_declaration_id"
                    class="pkp_form_element"
                    style="flex:1; min-width:200px;"
                    placeholder="{translate key="plugins.generic.aiDeclaration.form.existingDeclarationId.placeholder"}" />
                <button type="button" id="aiDeclarationFindBtn" class="pkp_button"
                    data-text-default="{translate key="plugins.generic.aiDeclaration.form.action.find"}"
                    data-text-loading="{translate key="plugins.generic.aiDeclaration.form.action.searching"}">
                    {translate key="plugins.generic.aiDeclaration.form.action.find"}
                </button>
            </div>
            <div id="aiDeclarationExistingStatus" class="ai-declaration-status" style="display:none;"></div>
        </div>
    </div>

    {* ---- AI sub-form ---- *}
    <div id="aiDeclarationSubForm" style="display:none;">

        {* Diagnostic questions → selected_checklist_ids (q1–q7), from API or static fallback *}
        <div class="ai-declaration-field">
            <label class="pkp_form_label">
                Preguntas de diagnóstico
            </label>
            <p class="ai-declaration-intro" style="margin-top:0; font-size:0.9em;">
                Marca las situaciones que aplicaron en tu uso de IA:
            </p>
            <div class="ai-declaration-checkboxes">
                {if !empty($aiDeclarationOptions.checklist)}
                    {foreach from=$aiDeclarationOptions.checklist item=citem}
                        <label class="ai-declaration-check-label">
                            <input type="checkbox" name="checklist_ids[]" value="{$citem.id|escape}" />
                             {$citem.question|escape}
                        </label>
                    {/foreach}
                {else}
                    {assign var=checklistFallback value=[
                        ["id"=>"q1","q"=>"¿Generó texto nuevo que usaste como base? (redacción)"],
                        ["id"=>"q2","q"=>"¿Te ayudó a escribir código o fórmulas? (programación)"],
                        ["id"=>"q3","q"=>"¿Resumió artículos o analizó PDFs? (análisis)"],
                        ["id"=>"q4","q"=>"¿Tradujo textos técnicos? (traducción)"],
                        ["id"=>"q5","q"=>"¿Sugirió estructuras o ideas? (ideación)"],
                        ["id"=>"q6","q"=>"¿Solo mejoró la redacción/ortografía? (apoyo a escritura)"],
                        ["id"=>"q7","q"=>"¿Evaluó tu trabajo buscando errores? (revisión)"]
                    ]}
                    {foreach from=$checklistFallback item=citem}
                        <label class="ai-declaration-check-label">
                            <input type="checkbox" name="checklist_ids[]" value="{$citem.id|escape}" />
                            <strong>{$citem.id|escape}</strong> &mdash; {$citem.q|escape}
                        </label>
                    {/foreach}
                {/if}
            </div>
        </div>

        {* Usage types — populated from API options or static fallback *}
        <div class="ai-declaration-field">
            <label class="pkp_form_label">
                {translate key="plugins.generic.aiDeclaration.form.usageTypes"} <span class="req">*</span>
            </label>
            <div class="ai-declaration-checkboxes">
                {if !empty($aiDeclarationOptions.usage_types)}
                    {foreach from=$aiDeclarationOptions.usage_types item=utype}
                        <label class="ai-declaration-check-label">
                            <input type="checkbox" name="usage_types[]" value="{$utype.id|escape}" />
                            {$utype.label|escape}
                        </label>
                    {/foreach}
                {else}
                    {foreach from=["draft","coauthor","writing-support","ideation","analysis","coding","translation","review","other"] item=utval}
                        <label class="ai-declaration-check-label">
                            <input type="checkbox" name="usage_types[]" value="{$utval|escape}" />
                            {translate key="plugins.generic.aiDeclaration.usageType.`$utval`"}
                        </label>
                    {/foreach}
                {/if}
            </div>
            <div id="customUsageTypeWrapper" style="display:none; margin-top:6px;">
                <input type="text" name="custom_usage_type" id="custom_usage_type"
                    class="pkp_form_element"
                    placeholder="{translate key="plugins.generic.aiDeclaration.form.customUsageType.placeholder"}" />
            </div>
        </div>

        {* AI Tool *}
        <div class="ai-declaration-field">
            <label class="pkp_form_label">
                {translate key="plugins.generic.aiDeclaration.form.aiTool"} <span class="req">*</span>
            </label>
            <div class="ai-declaration-tool-row">
                <div class="ai-declaration-tool-col">
                    <label class="sub_label" for="ai_tool_name">
                        {translate key="plugins.generic.aiDeclaration.form.aiTool.name"} <span class="req">*</span>
                    </label>
                    <input type="text" name="ai_tool_name" id="ai_tool_name"
                        class="pkp_form_element" placeholder="ChatGPT, Claude, Gemini…" />
                </div>
                <div class="ai-declaration-tool-col">
                    <label class="sub_label" for="ai_tool_version">
                        {translate key="plugins.generic.aiDeclaration.form.aiTool.version"}
                    </label>
                    <input type="text" name="ai_tool_version" id="ai_tool_version"
                        class="pkp_form_element" placeholder="4o, Sonnet 4.5…" />
                </div>
                <div class="ai-declaration-tool-col">
                    <label class="sub_label" for="ai_tool_provider">
                        {translate key="plugins.generic.aiDeclaration.form.aiTool.provider"}
                    </label>
                    <input type="text" name="ai_tool_provider" id="ai_tool_provider"
                        class="pkp_form_element" placeholder="OpenAI, Anthropic…" />
                </div>
            </div>
            <div class="ai-declaration-tool-row" style="margin-top:8px;">
                <div class="ai-declaration-tool-col">
                    <label class="sub_label" for="ai_tool_date_month">
                        {translate key="plugins.generic.aiDeclaration.form.aiTool.month"} <span class="req">*</span>
                    </label>
                    <select name="ai_tool_date_month" id="ai_tool_date_month" class="pkp_form_element">
                        <option value="">{translate key="plugins.generic.aiDeclaration.form.selectAnOption"}</option>
                        {foreach from=[1,2,3,4,5,6,7,8,9,10,11,12] item=m}
                            <option value="{$m}">{$m}</option>
                        {/foreach}
                    </select>
                </div>
                <div class="ai-declaration-tool-col">
                    <label class="sub_label" for="ai_tool_date_year">
                        {translate key="plugins.generic.aiDeclaration.form.aiTool.year"} <span class="req">*</span>
                    </label>
                    <select name="ai_tool_date_year" id="ai_tool_date_year" class="pkp_form_element">
                        <option value="">{translate key="plugins.generic.aiDeclaration.form.selectAnOption"}</option>
                        {foreach from=$aiDeclarationYears item=y}
                            <option value="{$y}">{$y}</option>
                        {/foreach}
                    </select>
                </div>
            </div>
        </div>

        {* Specific purpose *}
        <div class="ai-declaration-field">
            <label class="pkp_form_label" for="specific_purpose">
                {translate key="plugins.generic.aiDeclaration.form.specificPurpose"} <span class="req">*</span>
            </label>
            <textarea name="specific_purpose" id="specific_purpose"
                class="pkp_form_element" rows="3"
                placeholder="{translate key="plugins.generic.aiDeclaration.form.specificPurpose.placeholder"}"></textarea>
        </div>

        {* Prompts (dynamic) *}
        <div class="ai-declaration-field">
            <label class="pkp_form_label">
                {translate key="plugins.generic.aiDeclaration.form.prompts"} <span class="req">*</span>
            </label>
            <div id="aiDeclarationPromptsList">
                <div class="ai-declaration-prompt-row">
                    <textarea name="prompt_description[]"
                        class="pkp_form_element ai-declaration-prompt-input"
                        rows="2"
                        placeholder="{translate key="plugins.generic.aiDeclaration.form.prompt.placeholder"}"></textarea>
                    <button type="button" class="pkp_button ai-declaration-remove-prompt" style="display:none;"
                        title="{translate key="plugins.generic.aiDeclaration.form.prompt.remove"}">&#x2715;</button>
                </div>
            </div>
            <button type="button" class="pkp_button pkp_button_offset" id="aiDeclarationAddPrompt">
                + {translate key="plugins.generic.aiDeclaration.form.prompt.add"}
            </button>
        </div>

        {* Content use modes — numeric IDs (0–5) from API or static fallback *}
        <div class="ai-declaration-field">
            <label class="pkp_form_label">{translate key="plugins.generic.aiDeclaration.form.contentUseModes"}</label>
            <div class="ai-declaration-checkboxes">
                {if !empty($aiDeclarationOptions.content_use_modes)}
                    {foreach from=$aiDeclarationOptions.content_use_modes item=cmode}
                        <label class="ai-declaration-check-label">
                            <input type="checkbox" name="content_use_modes[]" value="{$cmode.id}" />
                            {$cmode.label|escape}
                        </label>
                    {/foreach}
                {else}
                    {assign var=modesFallback value=[
                        ["id"=>0,"label"=>"Incorporado tal cual (Verbatim)"],
                        ["id"=>1,"label"=>"Editado parcialmente (ajustes menores)"],
                        ["id"=>2,"label"=>"Reescrito sustancialmente"],
                        ["id"=>3,"label"=>"Usado solo como inspiración/referencia"],
                        ["id"=>4,"label"=>"Sintetizado con otras fuentes"],
                        ["id"=>5,"label"=>"Otro"]
                    ]}
                    {foreach from=$modesFallback item=cmode}
                        <label class="ai-declaration-check-label">
                            <input type="checkbox" name="content_use_modes[]" value="{$cmode.id}" />
                            {$cmode.label|escape}
                        </label>
                    {/foreach}
                {/if}
            </div>
            <div id="customContentUseModeWrapper" style="display:none; margin-top:6px;">
                <input type="text" name="custom_content_use_mode" id="custom_content_use_mode"
                    class="pkp_form_element"
                    placeholder="{translate key="plugins.generic.aiDeclaration.form.customContentUseMode.placeholder"}" />
            </div>
        </div>

        {* Content use context *}
        <div class="ai-declaration-field">
            <label class="pkp_form_label" for="content_use_context">
                {translate key="plugins.generic.aiDeclaration.form.contentUseContext"}
            </label>
            <textarea name="content_use_context" id="content_use_context"
                class="pkp_form_element" rows="2"
                placeholder="{translate key="plugins.generic.aiDeclaration.form.contentUseContext.placeholder"}"></textarea>
        </div>

        {* Human review *}
        <div class="ai-declaration-field">
            <label class="pkp_form_label" for="human_review_level">
                {translate key="plugins.generic.aiDeclaration.form.humanReview.level"}
            </label>
            <select name="human_review_level" id="human_review_level" class="pkp_form_element">
                {if !empty($aiDeclarationOptions.human_review_levels)}
                    {foreach from=$aiDeclarationOptions.human_review_levels item=lvl}
                        <option value="{$lvl.id}">{$lvl.label|escape}</option>
                    {/foreach}
                {else}
                    {foreach from=[0,1,2,3,4,5,6] item=lvl}
                        <option value="{$lvl}">
                            {translate key="plugins.generic.aiDeclaration.humanReview.level.`$lvl`"}
                        </option>
                    {/foreach}
                {/if}
            </select>
            <div id="humanReviewerFields" style="display:none; margin-top:8px;" class="ai-declaration-tool-row">
                <div class="ai-declaration-tool-col">
                    <label class="sub_label" for="human_review_reviewer_name">
                        {translate key="plugins.generic.aiDeclaration.form.humanReview.reviewerName"}
                    </label>
                    <input type="text" name="human_review_reviewer_name" id="human_review_reviewer_name"
                        class="pkp_form_element" />
                </div>
                <div class="ai-declaration-tool-col">
                    <label class="sub_label" for="human_review_reviewer_role">
                        {translate key="plugins.generic.aiDeclaration.form.humanReview.reviewerRole"}
                    </label>
                    <input type="text" name="human_review_reviewer_role" id="human_review_reviewer_role"
                        class="pkp_form_element"
                        placeholder="{translate key="plugins.generic.aiDeclaration.form.humanReview.reviewerRole.placeholder"}" />
                </div>
            </div>
        </div>

        {* License *}
        <div class="ai-declaration-field">
            <label class="pkp_form_label" for="license">
                {translate key="plugins.generic.aiDeclaration.form.license"}
            </label>
            <select name="license" id="license" class="pkp_form_element">
                {assign var=licenses value=["None","CC BY 4.0","CC BY-SA 4.0","CC BY-NC 4.0","CC BY-NC-SA 4.0","CC BY-ND 4.0","CC BY-NC-ND 4.0","CC0","Copyright"]}
                {foreach from=$licenses item=lic}
                    <option value="{$lic|escape}">{$lic|escape}</option>
                {/foreach}
            </select>
        </div>

        {* ---- Create declaration button ---- *}
        <div class="ai-declaration-action-row">
            <button type="button" id="aiDeclarationCreateBtn" class="pkp_button ai-declaration-action-btn"
                data-text-default="{translate key="plugins.generic.aiDeclaration.form.action.create"}"
                data-text-loading="{translate key="plugins.generic.aiDeclaration.form.action.creating"}">
                {translate key="plugins.generic.aiDeclaration.form.action.create"}
            </button>
            <div id="aiDeclarationCreateStatus" class="ai-declaration-status" style="display:none;"></div>
        </div>

    </div>{* end #aiDeclarationSubForm *}

    {* ---- Confirmed declaration badge (shown after any successful action) ---- *}
    <div id="aiDeclarationConfirmedBadge" class="ai-declaration-confirmed-badge" style="display:none;">
        <span class="ai-declaration-confirmed-icon">&#10003;</span>
        <span id="aiDeclarationConfirmedText"></span>
        <button type="button" id="aiDeclarationClearBtn" class="pkp_button pkp_button_offset ai-declaration-clear-btn">
            {translate key="plugins.generic.aiDeclaration.form.action.change"}
        </button>
    </div>

    {* ---- Client-side validation error ---- *}
    {* Messages stored in data-* attributes to avoid JS string / single-quote escaping issues *}
    <div id="aiDeclClientError" role="alert"
         data-msg-required="{translate key="plugins.generic.aiDeclaration.error.aiUsedRequired"|escape:"html"}"
         data-msg-unconfirmed="{translate key="plugins.generic.aiDeclaration.error.declarationNotConfirmed"|escape:"html"}"
         style="display:none; margin-top:1em; padding:0.7em 1em; background:#fde8e8; border:1px solid #e74c3c; border-radius:4px; color:#c0392b; font-weight:600; font-size:0.95em;">
    </div>

    {* ---- API unavailable bypass (shown after 3 consecutive failures) ---- *}
    <div id="aiDeclBypassSection" style="display:none; margin-top:1em; padding:0.8em 1em; background:#fff3cd; border:1px solid #ffc107; border-radius:4px;">
        <p style="margin:0 0 0.4em; color:#856404; font-weight:600;">
            {translate key="plugins.generic.aiDeclaration.error.apiUnavailable"}
        </p>
        <p style="margin:0 0 0.8em; font-size:0.9em; color:#856404;">
            {translate key="plugins.generic.aiDeclaration.error.apiUnavailableHint"}
        </p>
        <button type="button" id="aiDeclBypassBtn" class="pkp_button"
            data-pending-text="{translate key="plugins.generic.aiDeclaration.form.bypass.pending"|escape:"html"}">
            {translate key="plugins.generic.aiDeclaration.form.action.continueWithoutDeclaration"}
        </button>
    </div>

</div>{* end .ai-declaration-section *}

{* Inline JS — avoids jQuery AJAX eval issues with external <script src> in AJAX-loaded templates *}
<script type="text/javascript">
(function ($) {ldelim}
    'use strict';

    // ---- Configuration ----
    var createUrl = '{url router=$smarty.const.ROUTE_COMPONENT component=$aiDeclarationComponent op="manage" verb="ajaxCreateDeclaration" escape=false}';
    var findUrl   = '{url router=$smarty.const.ROUTE_COMPONENT component=$aiDeclarationComponent op="manage" verb="ajaxFindDeclaration" escape=false}';
    var submissionId = {$aiDeclarationSubmissionId|intval};

    // ---- Panel visibility ----
    function updatePanels(val) {ldelim}
        $('#aiDeclarationSubForm').toggle(val === '1');
        $('#aiDeclarationNoAiMsg').toggle(val === '0');
        $('#aiDeclarationExistingForm').toggle(val === 'existing');
    {rdelim}

    $(document).on('change', 'input[name="ai_used"]', function () {ldelim}
        updatePanels($(this).val());
    {rdelim});

    // Restore panels on load (e.g. after a validation error or returning to step 3)
    var $checked = $('input[name="ai_used"]:checked');
    if ($checked.length) {ldelim}
        updatePanels($checked.val());
    {rdelim}

    // ---- Confirmed badge ----
    function showBadge(id, url, hash) {ldelim}
        var $text = $('#aiDeclarationConfirmedText');
        var label = id ? id : '&mdash;';
        var html  = url
            ? '<a href="' + $('<span>').text(url).html() + '" target="_blank" rel="noopener">' + $('<span>').text(label).html() + '</a>'
            : $('<span>').text(label).html();
        if (hash) {ldelim}
            html += ' &nbsp;<code style="font-size:0.82em; color:#555;">' + $('<span>').text(hash).html() + '</code>';
        {rdelim}
        $text.html(html);
        $('#aiDeclarationConfirmedBadge').show();
    {rdelim}

    function storeConfirmed(id, hash, url) {ldelim}
        $('#aiDeclaration_confirmed_id').val(id || '');
        $('#aiDeclaration_confirmed_hash').val(hash || '');
        $('#aiDeclaration_confirmed_url').val(url || '');
        showBadge(id, url, hash);
    {rdelim}

    function clearConfirmed() {ldelim}
        $('#aiDeclaration_confirmed_id, #aiDeclaration_confirmed_hash, #aiDeclaration_confirmed_url').val('');
        $('#aiDeclarationConfirmedBadge').hide();
        $('#aiDeclarationConfirmedText').html('');
    {rdelim}

    // Show badge on load if there are pre-existing confirmed values
    (function () {ldelim}
        var id   = $('#aiDeclaration_confirmed_id').val();
        var hash = $('#aiDeclaration_confirmed_hash').val();
        var url  = $('#aiDeclaration_confirmed_url').val();
        if (id) {ldelim}
            showBadge(id, url, hash);
        {rdelim}
    {rdelim}());

    // Clear / "Change" button
    $(document).on('click', '#aiDeclarationClearBtn', function () {ldelim}
        clearConfirmed();
        // Also clear status messages
        $('.ai-declaration-status').hide().html('');
    {rdelim});

    // ---- API failure counter — bypass after 3 consecutive failures ----
    var apiFailCount = 0;

    function onApiFailure() {ldelim}
        apiFailCount++;
        if (apiFailCount >= 3) {ldelim}
            $('#aiDeclBypassSection').show();
        {rdelim}
    {rdelim}

    // ---- Generic AJAX helper ----
    function doAjax(url, formData, statusDiv, btn) {ldelim}
        btn.prop('disabled', true).text(btn.data('text-loading') || '…');
        if (statusDiv) statusDiv.hide().html('');

        $.ajax({ldelim}
            url:  url,
            type: 'POST',
            data: formData,
            success: function (data) {ldelim}
                var content = data.content || {ldelim}{rdelim};
                if (data.status && content.success) {ldelim}
                    apiFailCount = 0; // reset on success
                    storeConfirmed(
                        content.declaration_id  || '',
                        content.validation_hash || '',
                        content.declaration_url || ''
                    );
                    if (statusDiv) {ldelim}
                        var msg = content.declaration_id
                            ? '&#10003; {translate key="plugins.generic.aiDeclaration.form.action.successPrefix"|escape:"javascript"} <strong>' + $('<span>').text(content.declaration_id).html() + '</strong>'
                            : '&#10003; OK';
                        statusDiv.html('<span class="ai-decl-ok">' + msg + '</span>').show();
                    {rdelim}
                {rdelim} else {ldelim}
                    onApiFailure();
                    var errMsg = (content && content.error) ? content.error : 'Error desconocido';
                    if (statusDiv) {ldelim}
                        statusDiv.html('<span class="ai-decl-err">&#10007; ' + $('<span>').text(errMsg).html() + '</span>').show();
                    {rdelim}
                {rdelim}
            {rdelim},
            error: function (xhr) {ldelim}
                onApiFailure();
                if (statusDiv) {ldelim}
                    statusDiv.html('<span class="ai-decl-err">&#10007; Error HTTP ' + xhr.status + '</span>').show();
                {rdelim}
            {rdelim},
            complete: function () {ldelim}
                btn.prop('disabled', false).text(btn.data('text-default') || btn.text());
            {rdelim}
        {rdelim});
    {rdelim}

    // ---- Create declaration (AI used: ai_used=1) ----
    $(document).on('click', '#aiDeclarationCreateBtn', function () {ldelim}
        var $btn = $(this);

        // Client-side pre-validation
        var hasType  = $('input[name="usage_types[]"]:checked').length > 0;
        var toolName = $('#ai_tool_name').val().trim();
        var month    = $('#ai_tool_date_month').val();
        var year     = $('#ai_tool_date_year').val();
        var purpose  = $('#specific_purpose').val().trim();
        var hasPrompt = false;
        $('textarea[name="prompt_description[]"]').each(function () {ldelim}
            if ($(this).val().trim()) hasPrompt = true;
        {rdelim});

        var $status = $('#aiDeclarationCreateStatus');
        if (!hasType || !toolName || !month || !year || !purpose || !hasPrompt) {ldelim}
            $status.html('<span class="ai-decl-err">&#10007; Complete todos los campos marcados con * antes de crear la declaración.</span>').show();
            return;
        {rdelim}

        // If a declaration was already created, ask for confirmation before replacing it
        var existingId = $('#aiDeclaration_confirmed_id').val();
        if (existingId) {ldelim}
            if (!confirm('Ya existe una declaración registrada (ID: ' + existingId + ').\n\n¿Deseas crear una nueva declaración? La anterior quedará sin asociar a este envío.')) {ldelim}
                return;
            {rdelim}
        {rdelim}

        // Serialize all fields inside the sub-form + extra params
        var formData = $('#aiDeclarationSubForm').find('input:not([type=button]), select, textarea').serialize();
        formData += '&ai_used=1';
        formData += '&submissionId=' + encodeURIComponent(submissionId);
        formData += '&csrfToken='    + encodeURIComponent(pkp.currentUser.csrfToken);

        doAjax(createUrl, formData, $status, $btn);
    {rdelim});

    // ---- Register no-AI declaration (ai_used=0) ----
    $(document).on('click', '#aiDeclarationNoAiBtn', function () {ldelim}
        var existingId = $('#aiDeclaration_confirmed_id').val();
        if (existingId) {ldelim}
            if (!confirm('Ya existe una declaración registrada (ID: ' + existingId + ').\n\n¿Deseas registrar una nueva declaración sin IA? La anterior quedará sin asociar a este envío.')) {ldelim}
                return;
            {rdelim}
        {rdelim}

        var formData = 'ai_used=0'
            + '&submissionId=' + encodeURIComponent(submissionId)
            + '&csrfToken='    + encodeURIComponent(pkp.currentUser.csrfToken);

        doAjax(createUrl, formData, $('#aiDeclarationNoAiStatus'), $(this));
    {rdelim});

    // ---- Find existing declaration ----
    $(document).on('click', '#aiDeclarationFindBtn', function () {ldelim}
        var identifier = $('#existing_declaration_id').val().trim();
        var $status    = $('#aiDeclarationExistingStatus');

        if (!identifier) {ldelim}
            $status.html('<span class="ai-decl-err">&#10007; Introduce el ID o hash de tu declaración.</span>').show();
            return;
        {rdelim}

        var formData = 'existing_declaration_id=' + encodeURIComponent(identifier)
            + '&submissionId=' + encodeURIComponent(submissionId)
            + '&csrfToken='    + encodeURIComponent(pkp.currentUser.csrfToken);

        doAjax(findUrl, formData, $status, $(this));
    {rdelim});

    // ---- Misc field listeners ----

    // "other" usage type custom field
    $(document).on('change', 'input[name="usage_types[]"][value="other"]', function () {ldelim}
        $('#customUsageTypeWrapper').toggle($(this).is(':checked'));
    {rdelim});

    // Content use mode "Otro" (id=5) custom field
    $(document).on('change', 'input[name="content_use_modes[]"][value="5"]', function () {ldelim}
        $('#customContentUseModeWrapper').toggle($(this).is(':checked'));
    {rdelim});

    // Human review level — show reviewer fields when level > 0
    $(document).on('change', '#human_review_level', function () {ldelim}
        $('#humanReviewerFields').toggle(parseInt($(this).val(), 10) > 0);
    {rdelim});

    // Dynamic prompts — add
    $(document).on('click', '#aiDeclarationAddPrompt', function () {ldelim}
        var placeholder = $('#aiDeclarationPromptsList .ai-declaration-prompt-input').first().attr('placeholder');
        var $row        = $('<div class="ai-declaration-prompt-row"></div>');
        var $ta         = $('<textarea></textarea>').attr({ldelim}
            name: 'prompt_description[]', rows: 2, placeholder: placeholder
        {rdelim}).addClass('pkp_form_element ai-declaration-prompt-input');
        var $rm = $('<button type="button">&#x2715;</button>').addClass('pkp_button ai-declaration-remove-prompt');
        $row.append($ta).append($rm);
        $('#aiDeclarationPromptsList').append($row);
        updateRemoveButtons();
    {rdelim});

    // Dynamic prompts — remove
    $(document).on('click', '.ai-declaration-remove-prompt', function () {ldelim}
        $(this).closest('.ai-declaration-prompt-row').remove();
        updateRemoveButtons();
    {rdelim});

    function updateRemoveButtons() {ldelim}
        var $rows = $('#aiDeclarationPromptsList .ai-declaration-prompt-row');
        $rows.find('.ai-declaration-remove-prompt').toggle($rows.length > 1);
    {rdelim}

    updateRemoveButtons();

    // ---- Bypass button: allow continuing when API has repeatedly failed ----
    $(document).on('click', '#aiDeclBypassBtn', function () {ldelim}
        var pendingText = $(this).data('pending-text') || 'Pendiente';
        $('#aiDeclaration_bypass').val('1');
        // Show the confirmed badge with a pending message
        $('#aiDeclarationConfirmedText').html(
            '<em style="color:#856404;">' + $('<span>').text(pendingText).html() + '</em>'
        );
        $('#aiDeclarationConfirmedBadge').show();
        $('#aiDeclBypassSection').hide();
        $('#aiDeclClientError').hide();
    {rdelim});

    // ---- Client-side submit guard ----
    // Reads error messages from data-* attributes to avoid JS string escaping issues.
    var aiRequired = {if $aiDeclarationRequired}true{else}false{/if};

    function aiDeclShowError(msgKey) {ldelim}
        var $err = $('#aiDeclClientError');
        $err.text($err.attr(msgKey)).show();
        var sec = document.getElementById('aiDeclarationSection');
        if (sec) sec.scrollIntoView({ldelim}behavior: 'smooth', block: 'center'{rdelim});
    {rdelim}

    function aiDeclValidate() {ldelim}
        var aiUsed    = $('input[name="ai_used"]:checked').val() || '';
        var confirmed = $('#aiDeclaration_confirmed_id').val().trim();
        var bypass    = $('#aiDeclaration_bypass').val() === '1';
        $('#aiDeclClientError').hide();

        if (aiRequired && !aiUsed) {ldelim}
            aiDeclShowError('data-msg-required');
            return false;
        {rdelim}
        if (aiUsed && !confirmed && !bypass) {ldelim}
            aiDeclShowError('data-msg-unconfirmed');
            return false;
        {rdelim}
        return true;
    {rdelim}

    // Hide client error on radio change
    $(document).on('change', 'input[name="ai_used"]', function () {ldelim}
        $('#aiDeclClientError').hide();
    {rdelim});

    // Intercept the "Save and continue" button click (class added by OJS fbvFormButtons)
    $(document).on('click', '#submitStep3Form .submitFormButton', function (e) {ldelim}
        if (!aiDeclValidate()) {ldelim}
            e.preventDefault();
            return false;
        {rdelim}
    {rdelim});

{rdelim}(jQuery));
</script>
