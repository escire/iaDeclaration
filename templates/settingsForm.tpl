{**
 * Copyright 2026 eScire
 * Developed by eScire, with the collaboration of:
 *   - Gustavo Casiano Leon
 *   - Rebeca Maria Sirbu
 * Licensed under the Apache License, Version 2.0 (see LICENSE and NOTICE).
 *}
<script>
    $(function() {ldelim}
        $('#aiDeclarationSettingsForm').pkpHandler('$.pkp.controllers.form.AjaxFormHandler');
    {rdelim});
</script>

<div id="aiDeclarationSettings">
    <p>{translate key="plugins.generic.aiDeclaration.settings.description"}</p>

    <form class="pkp_form" id="aiDeclarationSettingsForm" method="post"
        action="{url router=$smarty.const.ROUTE_COMPONENT op="manage" category="generic" plugin=$pluginName verb="settings" save=true}">
        {csrf}
        {include file="controllers/notification/inPlaceNotification.tpl" notificationId="aiDeclarationSettingsFormNotification"}

        {fbvFormArea id="aiDeclarationSettingsFormArea"}

            {fbvFormSection title="plugins.generic.aiDeclaration.settings.declaradorUrl" for="declaradorUrl"}
                {fbvElement type="text" name="declaradorUrl" id="declaradorUrl" value=$declaradorUrl maxlength="255"
                    label="plugins.generic.aiDeclaration.settings.declaradorUrl.description"}
            {/fbvFormSection}

            {fbvFormSection title="plugins.generic.aiDeclaration.settings.apiKey" for="apiKey" required="true"}
                {fbvElement type="text" name="apiKey" id="apiKey" value=$apiKey maxlength="128"
                    label="plugins.generic.aiDeclaration.settings.apiKey.description"}
            {/fbvFormSection}

            {fbvFormSection list="true"}
                {fbvElement type="checkbox" name="requireDeclaration" id="requireDeclaration"
                    checked=$requireDeclaration
                    label="plugins.generic.aiDeclaration.settings.requireDeclaration"}
            {/fbvFormSection}

        {fbvFormButtons id="aiDeclarationSettingsFormSubmit" submitText="common.save"}
        {/fbvFormArea}
    </form>

    <div style="margin-top:1.5em; padding-top:1em; border-top:1px solid #ddd;">
        <p style="margin:0 0 0.5em; font-size:0.9em; color:#555;">
            {translate key="plugins.generic.aiDeclaration.settings.testConnection.hint"}
        </p>
        <button type="button" id="aiDeclarationTestBtn" class="pkp_button">
            {translate key="plugins.generic.aiDeclaration.settings.testConnection"}
        </button>
        <div id="aiDeclarationTestResult" style="margin-top:0.75em; font-size:0.88em; display:none;"></div>
    </div>
</div>

<script type="text/javascript">
(function ($) {ldelim}
    $('#aiDeclarationTestBtn').on('click', function () {ldelim}
        var btn = $(this);
        var result = $('#aiDeclarationTestResult');
        btn.prop('disabled', true).text('{translate key="plugins.generic.aiDeclaration.settings.testConnection.testing"}');
        result.hide();
        $.ajax({ldelim}
            url: '{url router=$smarty.const.ROUTE_COMPONENT op="manage" category="generic" plugin=$pluginName verb="testConnection" escape=false}',
            type: 'POST',
            data: {ldelim} csrfToken: $.pkp.app.csrfToken {rdelim},
            success: function (data) {ldelim}
                result.html(data.content).show();
            {rdelim},
            error: function (xhr) {ldelim}
                result.html('<span style="color:#c0392b;">Error inesperado: HTTP ' + xhr.status + '</span>').show();
            {rdelim},
            complete: function () {ldelim}
                btn.prop('disabled', false).text('{translate key="plugins.generic.aiDeclaration.settings.testConnection"}');
            {rdelim}
        {rdelim});
    {rdelim});
{rdelim}(jQuery));
</script>
