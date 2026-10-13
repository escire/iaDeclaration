{**
 * Copyright 2026 eScire
 * Developed by eScire, with the collaboration of:
 *   - Gustavo Casiano Leon
 *   - Rebeca Maria Sirbu
 * Licensed under the Apache License, Version 2.0 (see LICENSE and NOTICE).
 *}
{**
 * templates/submissionStep3.tpl
 *
 * AI Declaration panel injected in the submission wizard review step (step 5)
 * via the hook Template::SubmissionWizard::Section::Review (after 'editors' step).
 *
 * In OJS 3.4 the wizard is a Vue SPA — there is no traditional form POST.
 * Data is persisted exclusively through the AJAX pre-save calls below.
 *
 * Template variables assigned from PHP:
 *   $aiDeclarationRequired     bool   – Declaration is mandatory
 *   $aiDeclarationYears        array  – Range of selectable years
 *   $aiDeclarationPluginUrl    string – Plugin assets base URL
 *   $aiDeclarationComponent    string – Component path for AJAX URL routing
 *   $aiDeclarationSubmissionId int    – Current submission ID
 *   $aiDeclarationExisting     array  – Previously saved settings (if any)
 *   $aiDeclarationOptions      array  – Options from declarador API
 *}

{* Pre-populate state from previously saved settings *}
{assign var=aiDeclExistingId   value=$aiDeclarationExisting.aiDeclaration_id|default:""}
{assign var=aiDeclExistingHash value=$aiDeclarationExisting.aiDeclaration_hash|default:""}
{assign var=aiDeclExistingUrl  value=$aiDeclarationExisting.aiDeclaration_url|default:""}
{assign var=aiDeclExistingUsed value=$aiDeclarationExisting.aiDeclaration_used|default:""}

<div class="submissionWizard__reviewPanel panelSection" id="aiDeclarationSection"
     data-create-url="{url router=$smarty.const.ROUTE_COMPONENT component=$aiDeclarationComponent op="manage" verb="ajaxCreateDeclaration" escape=false}"
     data-find-url="{url router=$smarty.const.ROUTE_COMPONENT component=$aiDeclarationComponent op="manage" verb="ajaxFindDeclaration" escape=false}"
     data-submission-id="{$aiDeclarationSubmissionId|intval}"
     data-required="{if $aiDeclarationRequired}1{else}0{/if}"
     data-existing-id="{$aiDeclExistingId|escape}"
     data-existing-hash="{$aiDeclExistingHash|escape}"
     data-existing-url="{$aiDeclExistingUrl|escape}">

    <div class="submissionWizard__reviewPanel__header">
        <h3 id="reviewAiDeclaration">
            {translate key="plugins.generic.aiDeclaration.form.title"}
            {if $aiDeclarationRequired}<span class="req"> *</span>{/if}
        </h3>
    </div>

    <div class="submissionWizard__reviewPanel__body submissionWizard__reviewPanel__body--aiDeclaration" style="padding:1.5em;">

        <p class="ai-declaration-intro">
            {translate key="plugins.generic.aiDeclaration.form.intro"}
        </p>

        {* ---- Notice: review previous steps ---- *}
        <div
         class="aiDeclarationPreviousStepsNotice"
         style="margin: 1em 0; padding: 1em 1.25em; border: 1px solid #b8daff; border-left: 4px solid #007bff; border-radius: 4px; background-color: #eaf4ff; color: #1c3d5a;"
        >
         {translate key="plugins.generic.aiDeclaration.form.previousStepsNotice"}
        </div>

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
            <button type="button" id="aiDeclarationNoAiBtn" class="pkpButton inline-flex relative items-center gap-x-1 text-lg-semibold bg-primary border-transparent text-on-dark hover:bg-hover hover:text-on-dark disabled:bg-disabled disabled:text-disabled py-[0.4375rem] px-3 border rounded"
                data-text-default="{translate key="plugins.generic.aiDeclaration.form.action.registerNoAi"}"
                data-text-loading="{translate key="plugins.generic.aiDeclaration.form.action.registering"}">
                {translate key="plugins.generic.aiDeclaration.form.action.registerNoAi"}
            </button>
            <div id="aiDeclarationNoAiStatus" class="ai-declaration-status" style="display:none;"></div>
        </div>

        {* ---- Existing declaration panel ---- *}
        <div id="aiDeclarationExistingForm" style="display:none;">
            <div class="ai-declaration-field">
                <label class="pkpFormFieldLabel" for="existing_declaration_id">
                    {translate key="plugins.generic.aiDeclaration.form.existingDeclarationId"} <span class="req">*</span>
                </label>
                <p class="ai-declaration-intro" style="margin-top:0;">
                    {translate key="plugins.generic.aiDeclaration.form.existingDeclarationId.hint"}
                </p>
                <div style="display:flex; gap:0.75em; align-items:flex-start; flex-wrap:wrap;">
                    <input type="text" name="existing_declaration_id" id="existing_declaration_id"
                        class="pkpFormField__input"
                        style="flex:1; min-width:200px;"
                        placeholder="{translate key="plugins.generic.aiDeclaration.form.existingDeclarationId.placeholder"}" />
                    <button type="button" id="aiDeclarationFindBtn" class="pkpButton inline-flex relative items-center gap-x-1 text-lg-semibold bg-primary border-transparent text-on-dark hover:bg-hover hover:text-on-dark disabled:bg-disabled disabled:text-disabled py-[0.4375rem] px-3 border rounded"
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

            {* Diagnostic questions *}
            <div class="ai-declaration-field">
                <label class="pkpFormFieldLabel">Preguntas de diagnóstico</label>
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

            {* Usage types *}
            <div class="ai-declaration-field">
                <label class="pkpFormFieldLabel">
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
                        class="pkpFormField__input"
                        placeholder="{translate key="plugins.generic.aiDeclaration.form.customUsageType.placeholder"}" />
                </div>
            </div>

            {* AI Tool *}
            <div class="ai-declaration-field">
                <label class="pkpFormFieldLabel">
                    {translate key="plugins.generic.aiDeclaration.form.aiTool"} <span class="req">*</span>
                </label>
                <div class="ai-declaration-tool-row">
                    <div class="ai-declaration-tool-col">
                        <label class="sub_label" for="ai_tool_name">
                            {translate key="plugins.generic.aiDeclaration.form.aiTool.name"} <span class="req">*</span>
                        </label>
                        <input type="text" name="ai_tool_name" id="ai_tool_name"
                            class="pkpFormField__input" placeholder="ChatGPT, Claude, Gemini…" />
                    </div>
                    <div class="ai-declaration-tool-col">
                        <label class="sub_label" for="ai_tool_version">
                            {translate key="plugins.generic.aiDeclaration.form.aiTool.version"}
                        </label>
                        <input type="text" name="ai_tool_version" id="ai_tool_version"
                            class="pkpFormField__input" placeholder="4o, Sonnet 4.5…" />
                    </div>
                    <div class="ai-declaration-tool-col">
                        <label class="sub_label" for="ai_tool_provider">
                            {translate key="plugins.generic.aiDeclaration.form.aiTool.provider"}
                        </label>
                        <input type="text" name="ai_tool_provider" id="ai_tool_provider"
                            class="pkpFormField__input" placeholder="OpenAI, Anthropic…" />
                    </div>
                </div>
                <div class="ai-declaration-tool-row" style="margin-top:8px;">
                    <div class="ai-declaration-tool-col">
                        <label class="sub_label" for="ai_tool_date_month">
                            {translate key="plugins.generic.aiDeclaration.form.aiTool.month"} <span class="req">*</span>
                        </label>
                        <select name="ai_tool_date_month" id="ai_tool_date_month" class="pkpFormField__input">
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
                        <select name="ai_tool_date_year" id="ai_tool_date_year" class="pkpFormField__input">
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
                <label class="pkpFormFieldLabel" for="specific_purpose">
                    {translate key="plugins.generic.aiDeclaration.form.specificPurpose"} <span class="req">*</span>
                </label>
                <textarea name="specific_purpose" id="specific_purpose"
                    class="pkpFormField__input" rows="3"
                    placeholder="{translate key="plugins.generic.aiDeclaration.form.specificPurpose.placeholder"}"></textarea>
            </div>

            {* Prompts (dynamic) *}
            <div class="ai-declaration-field">
                <label class="pkpFormFieldLabel">
                    {translate key="plugins.generic.aiDeclaration.form.prompts"} <span class="req">*</span>
                </label>
                <div id="aiDeclarationPromptsList">
                    <div class="ai-declaration-prompt-row">
                        <textarea name="prompt_description[]"
                            class="pkpFormField__input ai-declaration-prompt-input"
                            rows="2"
                            placeholder="{translate key="plugins.generic.aiDeclaration.form.prompt.placeholder"}"></textarea>
                        <button type="button" class="pkpButton inline-flex relative items-center gap-x-1 text-lg-semibold text-primary border-light hover:text-hover disabled:text-disabled bg-secondary py-[0.4375rem] px-3 border rounded ai-declaration-remove-prompt" style="display:none;"
                            title="{translate key="plugins.generic.aiDeclaration.form.prompt.remove"}">&#x2715;</button>
                    </div>
                </div>
                <button type="button" class="pkpButton inline-flex relative items-center gap-x-1 text-lg-semibold text-primary border-light hover:text-hover disabled:text-disabled bg-secondary py-[0.4375rem] px-3 border rounded" id="aiDeclarationAddPrompt">
                    + {translate key="plugins.generic.aiDeclaration.form.prompt.add"}
                </button>
            </div>

            {* Content use modes *}
            <div class="ai-declaration-field">
                <label class="pkpFormFieldLabel">{translate key="plugins.generic.aiDeclaration.form.contentUseModes"}</label>
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
                        class="pkpFormField__input"
                        placeholder="{translate key="plugins.generic.aiDeclaration.form.customContentUseMode.placeholder"}" />
                </div>
            </div>

            {* Content use context *}
            <div class="ai-declaration-field">
                <label class="pkpFormFieldLabel" for="content_use_context">
                    {translate key="plugins.generic.aiDeclaration.form.contentUseContext"}
                </label>
                <textarea name="content_use_context" id="content_use_context"
                    class="pkpFormField__input" rows="2"
                    placeholder="{translate key="plugins.generic.aiDeclaration.form.contentUseContext.placeholder"}"></textarea>
            </div>

            {* Human review *}
            <div class="ai-declaration-field">
                <label class="pkpFormFieldLabel" for="human_review_level">
                    {translate key="plugins.generic.aiDeclaration.form.humanReview.level"}
                </label>
                <select name="human_review_level" id="human_review_level" class="pkpFormField__input">
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
                            class="pkpFormField__input" />
                    </div>
                    <div class="ai-declaration-tool-col">
                        <label class="sub_label" for="human_review_reviewer_role">
                            {translate key="plugins.generic.aiDeclaration.form.humanReview.reviewerRole"}
                        </label>
                        <input type="text" name="human_review_reviewer_role" id="human_review_reviewer_role"
                            class="pkpFormField__input"
                            placeholder="{translate key="plugins.generic.aiDeclaration.form.humanReview.reviewerRole.placeholder"}" />
                    </div>
                </div>
            </div>

            {* License *}
            <div class="ai-declaration-field">
                <label class="pkpFormFieldLabel" for="license">
                    {translate key="plugins.generic.aiDeclaration.form.license"}
                </label>
                <select name="license" id="license" class="pkpFormField__input">
                    {assign var=licenses value=["None","CC BY 4.0","CC BY-SA 4.0","CC BY-NC 4.0","CC BY-NC-SA 4.0","CC BY-ND 4.0","CC BY-NC-ND 4.0","CC0","Copyright"]}
                    {foreach from=$licenses item=lic}
                        <option value="{$lic|escape}">{$lic|escape}</option>
                    {/foreach}
                </select>
            </div>

            {* Create declaration button *}
            <div class="ai-declaration-action-row">
                <button type="button" id="aiDeclarationCreateBtn" class="pkpButton inline-flex relative items-center gap-x-1 text-lg-semibold bg-primary border-transparent text-on-dark hover:bg-hover hover:text-on-dark disabled:bg-disabled disabled:text-disabled py-[0.4375rem] px-3 border rounded"
                    data-text-default="{translate key="plugins.generic.aiDeclaration.form.action.create"}"
                    data-text-loading="{translate key="plugins.generic.aiDeclaration.form.action.creating"}">
                    {translate key="plugins.generic.aiDeclaration.form.action.create"}
                </button>
                <div id="aiDeclarationCreateStatus" class="ai-declaration-status" style="display:none;"></div>
            </div>

        </div>{* end #aiDeclarationSubForm *}

        {* Confirmed declaration badge (shown after any successful action) *}
        <div id="aiDeclarationConfirmedBadge" class="ai-declaration-confirmed-badge"
            style="{if $aiDeclExistingId}display:block;{else}display:none;{/if}">
            <span class="ai-declaration-confirmed-icon">&#10003;</span>
            <span id="aiDeclarationConfirmedText">
                {if $aiDeclExistingId}
                    {if $aiDeclExistingUrl}
                        <a href="{$aiDeclExistingUrl|escape}" target="_blank" rel="noopener">{$aiDeclExistingId|escape}</a>
                    {else}
                        {$aiDeclExistingId|escape}
                    {/if}
                    {if $aiDeclExistingHash}
                        &nbsp;<code style="font-size:0.82em; color:#555;">{$aiDeclExistingHash|escape}</code>
                    {/if}
                {/if}
            </span>
            <button type="button" id="aiDeclarationClearBtn" class="pkpButton inline-flex relative items-center gap-x-1 text-lg-semibold text-primary border-light hover:text-hover disabled:text-disabled bg-secondary py-[0.4375rem] px-3 border rounded ai-declaration-clear-btn">
                {translate key="plugins.generic.aiDeclaration.form.action.change"}
            </button>
        </div>

        {* Client-side validation error *}
        <div id="aiDeclClientError" role="alert"
             data-msg-required="{translate key="plugins.generic.aiDeclaration.error.aiUsedRequired"|escape:"html"}"
             data-msg-unconfirmed="{translate key="plugins.generic.aiDeclaration.error.declarationNotConfirmed"|escape:"html"}"
             style="display:none; margin-top:1em; padding:0.7em 1em; background:#fde8e8; border:1px solid #e74c3c; border-radius:4px; color:#c0392b; font-weight:600; font-size:0.95em;">
        </div>

        {* API unavailable bypass *}
        <div id="aiDeclBypassSection" style="display:none; margin-top:1em; padding:0.8em 1em; background:#fff3cd; border:1px solid #ffc107; border-radius:4px;">
            <p style="margin:0 0 0.4em; color:#856404; font-weight:600;">
                {translate key="plugins.generic.aiDeclaration.error.apiUnavailable"}
            </p>
            <p style="margin:0 0 0.8em; font-size:0.9em; color:#856404;">
                {translate key="plugins.generic.aiDeclaration.error.apiUnavailableHint"}
            </p>
            <button type="button" id="aiDeclBypassBtn" class="pkpButton inline-flex relative items-center gap-x-1 text-lg-semibold text-primary border-light hover:text-hover disabled:text-disabled bg-secondary py-[0.4375rem] px-3 border rounded"
                data-pending-text="{translate key="plugins.generic.aiDeclaration.form.bypass.pending"|escape:"html"}">
                {translate key="plugins.generic.aiDeclaration.form.action.continueWithoutDeclaration"}
            </button>
        </div>

    </div>{* end .submissionWizard__reviewPanel__body *}
</div>{* end .submissionWizard__reviewPanel *}

{* JS is in assets/js/declarationWizard.js — loaded via TemplateManager::display hook. *}
{* Dynamic variables (AJAX URLs, submissionId, etc.) are passed via data-* attributes on #aiDeclarationSection. *}
