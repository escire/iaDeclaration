<?php
/**
 * Copyright 2026 eScire
 * Developed by eScire, with the collaboration of:
 *   - Gustavo Casiano Leon
 * Licensed under the Apache License, Version 2.0 (see LICENSE and NOTICE).
 */

/**
 * @file plugins/generic/aiDeclaration/AiDeclarationPlugin.inc.php
 *
 * @class AiDeclarationPlugin
 * @ingroup plugins_generic_aiDeclaration
 *
 * Plugin that integrates an AI transparency declaration form in submission step 3
 * and displays the declaration in the published article view.
 *
 * Three modes for the author:
 *   ai_used = '1'        → Create new declaration (AI was used)
 *   ai_used = '0'        → Create new declaration (AI was NOT used)
 *   ai_used = 'existing' → Retrieve an existing declaration by ID/hash
 *
 * Declaration creation/lookup is done via AJAX (verb=ajaxCreateDeclaration /
 * ajaxFindDeclaration) BEFORE the step 3 form is saved. The confirmed declaration
 * data is stored in hidden fields and persisted in execute().
 */

import('lib.pkp.classes.plugins.GenericPlugin');

class AiDeclarationPlugin extends GenericPlugin
{
    public function register($category, $path, $mainContextId = null)
    {
        $success = parent::register($category, $path, $mainContextId);

        if (!Config::getVar('general', 'installed') || defined('RUNNING_UPGRADE')) {
            return true;
        }

        if ($success && $this->getEnabled($mainContextId)) {
            HookRegistry::register(
                'Templates::Submission::SubmissionMetadataForm::AdditionalMetadata',
                array($this, 'addDeclarationFormToStep3')
            );
            HookRegistry::register(
                'submissionsubmitstep3form::validate',
                array($this, 'validateDeclarationStep3')
            );
            HookRegistry::register(
                'submissionsubmitstep3form::execute',
                array($this, 'executeDeclarationStep3')
            );
            HookRegistry::register(
                'Templates::Article::Details',
                array($this, 'addDeclarationToArticle')
            );
            HookRegistry::register(
                'Template::Workflow::Publication',
                array($this, 'addDeclarationTabToWorkflow')
            );
            // Allow the AJAX component handler to be accessed by any logged-in user
            HookRegistry::register(
                'LoadComponentHandler',
                array($this, 'setupComponentHandler')
            );
        }

        return $success;
    }

    public function getCanEnable()
    {
        return ((bool) Application::get()->getRequest()->getContext());
    }

    public function getCanDisable()
    {
        return ((bool) Application::get()->getRequest()->getContext());
    }

    public function getDisplayName()
    {
        return __('plugins.generic.aiDeclaration.displayName');
    }

    public function getDescription()
    {
        return __('plugins.generic.aiDeclaration.description');
    }

    /**
     * Hook: LoadComponentHandler — intercept requests to AiDeclarationHandler
     * so the PKPComponentRouter can load it from the plugin directory.
     */
    public function setupComponentHandler($hookName, $params)
    {
        $component = &$params[0];
        $expectedComponent = str_replace('/', '.', $this->getPluginPath())
            . '.classes.AiDeclarationHandler';
        if ($component === $expectedComponent) {
            return true; // Skip default file lookup; instantiate() will use import()
        }
        return false;
    }

    // -------------------------------------------------------------------------
    // Hook callbacks
    // -------------------------------------------------------------------------

    /**
     * Hook: insert declaration form at the end of submission step 3 metadata form.
     */
    public function addDeclarationFormToStep3($hookName, $params)
    {
        $request     = PKPApplication::get()->getRequest();
        $templateMgr = TemplateManager::getManager($request);
        $contextId   = $request->getContext()->getId();

        $currentYear = (int) date('Y');
        $pluginUrl   = $request->getBaseUrl() . '/' . $this->getPluginPath();

        // Get current submission ID for AJAX calls
        $submissionId = (int) $request->getUserVar('submissionId');

        // Pre-load existing declaration settings (when author returns to step 3)
        $existingSettings = array();
        if ($submissionId) {
            $submissionDao = DAORegistry::getDAO('SubmissionDAO');
            $sub = $submissionDao->getById($submissionId);
            if ($sub) {
                $pub = $sub->getCurrentPublication();
                if ($pub) {
                    $existingSettings = $this->_loadDeclarationSettings($pub->getId());
                }
            }
        }

        // Component path for AiDeclarationHandler (accessible by logged-in authors).
        // PKPComponentRouter maps dots→slashes and strips trailing 'Handler':
        //   plugins.generic.aiDeclaration.classes.AiDeclarationHandler
        //   → $$$call$$$/plugins/generic/ai-declaration/classes/ai-declaration/manage
        $handlerComponent = str_replace('/', '.', $this->getPluginPath())
            . '.classes.AiDeclarationHandler';

        // Fetch available options from the API (usage_types, content_use_modes, etc.)
        $apiOptions    = array();
        $apiKey        = (string) $this->getSetting($contextId, 'apiKey');
        $declaradorUrl = (string) $this->getSetting($contextId, 'declaradorUrl');
        $langCode      = $this->resolveLangCode(AppLocale::getLocale());
        if (!empty($apiKey)) {
            import('plugins.generic.aiDeclaration.classes.DeclaradorApiClient');
            try {
                $client     = new DeclaradorApiClient($declaradorUrl);
                $apiOptions = $client->getOptions($apiKey, $langCode);
            } catch (Exception $e) {
                error_log('[aiDeclaration] getOptions failed: ' . $e->getMessage());
            }
        }

        $templateMgr->assign(array(
            'aiDeclarationRequired'     => (bool) $this->getSetting($contextId, 'requireDeclaration'),
            'aiDeclarationYears'        => range($currentYear, 2020),
            'aiDeclarationPluginUrl'    => $pluginUrl,
            'aiDeclarationPluginName'   => $this->getName(),
            'aiDeclarationComponent'    => $handlerComponent,
            'aiDeclarationSubmissionId' => $submissionId,
            'aiDeclarationExisting'     => $existingSettings,
            'aiDeclarationOptions'      => $apiOptions,
        ));

        $templateMgr->display($this->getTemplateResource('submissionStep3.tpl'));
        return false;
    }

    /**
     * Hook: validate step 3.
     *
     * With the AJAX-first flow, field-level validation happens client-side
     * before the AJAX call. Here we only check:
     *   1. If required, ai_used must be selected.
     *   2. If ai_used is selected and an API key is configured,
     *      aiDeclaration_confirmed_id must be non-empty (the AJAX action
     *      must have been completed before saving).
     */
    public function validateDeclarationStep3($hookName, $params)
    {
        $form    = &$params[0];
        $request = PKPApplication::get()->getRequest();
        $context = $request->getContext();

        $requireDeclaration = (bool) $this->getSetting($context->getId(), 'requireDeclaration');
        $apiKey             = (string) $this->getSetting($context->getId(), 'apiKey');
        $aiUsed             = $request->getUserVar('ai_used');

        // 1. If required and nothing selected
        if ($requireDeclaration && ($aiUsed === null || $aiUsed === '')) {
            $form->addErrorField('ai_used');
            $form->addError('ai_used', __('plugins.generic.aiDeclaration.error.aiUsedRequired'));
            return false;
        }

        // 2. If a choice was made, the author must complete the AJAX action first.
        if (!empty($aiUsed)) {
            $confirmedId = trim((string) $request->getUserVar('aiDeclaration_confirmed_id'));
            $bypass      = ($request->getUserVar('aiDeclaration_bypass') === '1');
            if (empty($confirmedId) && !$bypass) {
                // Block if: API key configured (declaration must be linked)
                //        OR: declaration is required (can't skip even without API key)
                if (!empty($apiKey) || $requireDeclaration) {
                    $form->addErrorField('ai_used');
                    $form->addError('ai_used', __('plugins.generic.aiDeclaration.error.declarationNotConfirmed'));
                }
            }
        }

        return false;
    }

    /**
     * Hook: save confirmed declaration data to publication_settings.
     *
     * At this point the declaration has already been registered in declarador
     * via AJAX. We just persist the IDs from the hidden confirmed fields.
     */
    public function executeDeclarationStep3($hookName, $params)
    {
        $form    = &$params[0];
        $request = PKPApplication::get()->getRequest();

        $aiUsed = $request->getUserVar('ai_used');
        if ($aiUsed === null || $aiUsed === '') {
            return false;
        }

        $submission  = $form->submission;
        $publication = $submission->getCurrentPublication();
        if (!$publication) {
            return false;
        }

        $confirmedId   = trim((string) $request->getUserVar('aiDeclaration_confirmed_id'));
        $confirmedHash = trim((string) $request->getUserVar('aiDeclaration_confirmed_hash'));
        $confirmedUrl  = trim((string) $request->getUserVar('aiDeclaration_confirmed_url'));
        $bypass        = ($request->getUserVar('aiDeclaration_bypass') === '1');

        $settings = array(
            'aiDeclaration_used' => $aiUsed === '0' ? '0' : '1',
            'aiDeclaration_id'   => $confirmedId,
            'aiDeclaration_hash' => $confirmedHash,
            'aiDeclaration_url'  => $confirmedUrl,
        );
        if ($bypass) {
            $settings['aiDeclaration_bypass'] = '1';
        }

        $this->_saveDeclarationSettings($publication->getId(), $settings);

        return false;
    }

    /**
     * Hook: display the declaration badge/section in the published article sidebar.
     */
    public function addDeclarationToArticle($hookName, $params)
    {
        $request     = PKPApplication::get()->getRequest();
        $templateMgr = TemplateManager::getManager($request);

        $submission = $templateMgr->getTemplateVars('article');
        if (!$submission) {
            return false;
        }

        $publication = $submission->getCurrentPublication();
        if (!$publication) {
            return false;
        }

        $settings = $this->_loadDeclarationSettings($publication->getId());
        $aiUsed   = isset($settings['aiDeclaration_used']) ? $settings['aiDeclaration_used'] : null;
        if ($aiUsed === null) {
            return false;
        }

        $templateMgr->assign(array(
            'aiDeclaration_used'  => (bool) $aiUsed,
            'aiDeclaration_id'    => isset($settings['aiDeclaration_id'])   ? $settings['aiDeclaration_id']   : '',
            'aiDeclaration_hash'  => isset($settings['aiDeclaration_hash']) ? $settings['aiDeclaration_hash'] : '',
            'aiDeclaration_url'   => isset($settings['aiDeclaration_url'])  ? $settings['aiDeclaration_url']  : '',
        ));

        $templateMgr->display($this->getTemplateResource('articleDeclaration.tpl'));
        return false;
    }

    /**
     * Hook: add an "AI Declaration" tab to the Publication panel in the editorial workflow.
     * Editors/managers can view the linked declaration and update its URL or ID.
     */
    public function addDeclarationTabToWorkflow($hookName, $params)
    {
        $request     = PKPApplication::get()->getRequest();
        $templateMgr = TemplateManager::getManager($request);

        $submission = $templateMgr->getTemplateVars('submission');
        if (!$submission) {
            return false;
        }

        $publication = $submission->getCurrentPublication();
        if (!$publication) {
            return false;
        }

        $handlerComponent = str_replace('/', '.', $this->getPluginPath())
            . '.classes.AiDeclarationHandler';

        $settings = $this->_loadDeclarationSettings($publication->getId());
        $hasRealDeclaration = !empty($settings['aiDeclaration_id'])
            || !empty($settings['aiDeclaration_hash'])
            || !empty($settings['aiDeclaration_url']);

        $templateMgr->assign(array(
            'aiDeclarationWorkflow'                   => $settings,
            'aiDeclarationWorkflowPubId'              => $publication->getId(),
            'aiDeclarationWorkflowIsPublished'        => ((int) $publication->getData('status') === STATUS_PUBLISHED),
            'aiDeclarationWorkflowHasRealDeclaration' => $hasRealDeclaration,
            'aiDeclarationComponent'                  => $handlerComponent,
        ));

        $templateMgr->display($this->getTemplateResource('workflowDeclaration.tpl'));
        return false;
    }

    // -------------------------------------------------------------------------
    // Settings / Plugin management
    // -------------------------------------------------------------------------

    public function getActions($request, $actionArgs)
    {
        $router = $request->getRouter();
        import('lib.pkp.classes.linkAction.request.AjaxModal');
        return array_merge(
            $this->getEnabled() ? array(
                new LinkAction(
                    'settings',
                    new AjaxModal(
                        $router->url(
                            $request,
                            null,
                            null,
                            'manage',
                            null,
                            array(
                                'verb'     => 'settings',
                                'plugin'   => $this->getName(),
                                'category' => 'generic',
                            )
                        ),
                        $this->getDisplayName()
                    ),
                    __('manager.plugins.settings'),
                    null
                ),
            ) : array(),
            parent::getActions($request, $actionArgs)
        );
    }

    public function manage($args, $request)
    {
        switch ($request->getUserVar('verb')) {

            case 'settings':
                $context = $request->getContext();
                $this->import('form.AiDeclarationSettingsForm');
                $form = new AiDeclarationSettingsForm($this, $context->getId());

                if ($request->getUserVar('save')) {
                    $form->readInputData();
                    if ($form->validate()) {
                        $form->execute();
                        return new JSONMessage(true);
                    }
                }

                return new JSONMessage(true, $form->fetch($request));

            case 'testConnection':
                $context       = $request->getContext();
                $apiKey        = (string) $this->getSetting($context->getId(), 'apiKey');
                $declaradorUrl = (string) $this->getSetting($context->getId(), 'declaradorUrl');

                import('plugins.generic.aiDeclaration.classes.DeclaradorApiClient');
                $client = new DeclaradorApiClient($declaradorUrl);
                $result = $client->ping($apiKey);

                $effectiveUrl = $result['url'];
                if ($result['ok']) {
                    $msg  = '<span style="color:#1e7e34;">&#10003; Conexión exitosa</span>';
                    $msg .= '<br><small>URL alcanzada: <code>' . htmlspecialchars($effectiveUrl) . '</code>';
                    $msg .= '<br>HTTP ' . ($result['httpCode'] === 404 ? '404 (esperado — el servidor responde correctamente)' : $result['httpCode']) . '</small>';
                } else {
                    $msg  = '<span style="color:#c0392b;">&#10007; Fallo de conexión</span>';
                    $msg .= '<br><small>URL intentada: <code>' . htmlspecialchars($effectiveUrl) . '</code>';
                    $msg .= '<br>Error: ' . htmlspecialchars($result['error']) . '</small>';
                    if ($result['httpCode'] === 401) {
                        $msg .= '<br><em>Nota: el servidor sí responde, pero la API key es incorrecta.</em>';
                    }
                }
                return new JSONMessage(true, $msg);

            case 'ajaxCreateDeclaration':
                return $this->_handleAjaxCreate($request);

            case 'ajaxFindDeclaration':
                return $this->_handleAjaxFind($request);

            case 'ajaxUpdateDeclarationMeta':
                return $this->_handleAjaxUpdateMeta($request);

            default:
                return parent::manage($args, $request);
        }
    }

    // -------------------------------------------------------------------------
    // AJAX handlers
    // -------------------------------------------------------------------------

    /**
     * AJAX: create a new declaration (ai_used=1 or ai_used=0) via declarador API.
     *
     * Expects POST: submissionId, ai_used, csrfToken, plus all declaration form fields.
     * Returns JSONMessage with the declarador API response.
     */
    private function _handleAjaxCreate($request)
    {
        $context       = $request->getContext();
        $apiKey        = (string) $this->getSetting($context->getId(), 'apiKey');
        $declaradorUrl = (string) $this->getSetting($context->getId(), 'declaradorUrl');
        $langCode      = $this->resolveLangCode($context->getPrimaryLocale());

        if (empty($apiKey)) {
            return new JSONMessage(false, array(
                'error' => __('plugins.generic.aiDeclaration.error.noApiKey'),
            ));
        }

        $submissionId  = (int) $request->getUserVar('submissionId');
        $submissionDao = DAORegistry::getDAO('SubmissionDAO');
        $submission    = $submissionDao->getById($submissionId);

        if (!$submission) {
            return new JSONMessage(false, array('error' => 'Submission not found'));
        }

        import('plugins.generic.aiDeclaration.classes.DeclaradorApiClient');
        import('plugins.generic.aiDeclaration.classes.DeclarationDataMapper');

        try {
            $mapper  = new DeclarationDataMapper();
            $payload = $mapper->mapFromRequest($request->getUserVars(), $submission, $langCode);

            $client = new DeclaradorApiClient($declaradorUrl);
            $result = $client->createDeclaration($payload, $apiKey);

            // Pre-save immediately so the declaration is linked to the publication
            // even before the author clicks "Save and continue".
            if (!empty($result['success']) && !empty($result['declaration_id'])) {
                $aiUsed      = ($request->getUserVar('ai_used') === '0') ? '0' : '1';
                $publication = $submission->getCurrentPublication();
                if ($publication) {
                    $this->_saveDeclarationSettings($publication->getId(), array(
                        'aiDeclaration_used' => $aiUsed,
                        'aiDeclaration_id'   => (string) $result['declaration_id'],
                        'aiDeclaration_hash' => (string) ($result['validation_hash'] ?? ''),
                        'aiDeclaration_url'  => (string) ($result['declaration_url']  ?? ''),
                    ));
                }
            }

            return new JSONMessage(true, $result);
        } catch (Exception $e) {
            error_log('aiDeclaration ajaxCreate error: ' . $e->getMessage());
            return new JSONMessage(false, array('error' => $e->getMessage()));
        }
    }

    /**
     * AJAX: retrieve an existing declaration from declarador API.
     *
     * Expects POST: existing_declaration_id, submissionId, csrfToken.
     * Returns JSONMessage with the declarador API response.
     */
    private function _handleAjaxFind($request)
    {
        $context       = $request->getContext();
        $apiKey        = (string) $this->getSetting($context->getId(), 'apiKey');
        $declaradorUrl = (string) $this->getSetting($context->getId(), 'declaradorUrl');
        $langCode      = $this->resolveLangCode($context->getPrimaryLocale());

        $identifier = trim((string) $request->getUserVar('existing_declaration_id'));
        if (empty($identifier)) {
            return new JSONMessage(false, array(
                'error' => __('plugins.generic.aiDeclaration.error.existingDeclarationIdRequired'),
            ));
        }

        if (empty($apiKey)) {
            return new JSONMessage(false, array(
                'error' => __('plugins.generic.aiDeclaration.error.noApiKey'),
            ));
        }

        import('plugins.generic.aiDeclaration.classes.DeclaradorApiClient');

        try {
            $client = new DeclaradorApiClient($declaradorUrl);
            $result = $client->getDeclaration($identifier, $apiKey, $langCode);
            return new JSONMessage(true, $result);
        } catch (Exception $e) {
            error_log('aiDeclaration ajaxFind error: ' . $e->getMessage());
            return new JSONMessage(false, array('error' => $e->getMessage()));
        }
    }

    /**
     * AJAX: update declaration metadata (URL and/or ID) for a given publication.
     * Only accessible to managers and sub-editors.
     *
     * Expects POST: publicationId, aiDeclaration_url, aiDeclaration_id, csrfToken.
     */
    private function _handleAjaxUpdateMeta($request)
    {
        import('lib.pkp.classes.core.JSONMessage');

        if (!$request->checkCSRF()) {
            return new JSONMessage(false, array('error' => 'Invalid CSRF token'));
        }

        // Require manager or sub-editor role
        $user    = $request->getUser();
        $context = $request->getContext();
        if (!$user || !$context) {
            return new JSONMessage(false, array('error' => 'Not authenticated'));
        }
        $roleDao = DAORegistry::getDAO('RoleDAO');
        if (!$roleDao->userHasRole($context->getId(), $user->getId(), ROLE_ID_MANAGER) &&
            !$roleDao->userHasRole($context->getId(), $user->getId(), ROLE_ID_SUB_EDITOR)) {
            return new JSONMessage(false, array('error' => 'Access denied'));
        }

        $publicationId = (int) $request->getUserVar('publicationId');
        if (!$publicationId) {
            return new JSONMessage(false, array('error' => 'Publication ID required'));
        }

        // Block edits on published publications that already have a real declaration
        $publicationDao = DAORegistry::getDAO('PublicationDAO');
        $publication    = $publicationDao->getById($publicationId);
        if (!$publication) {
            return new JSONMessage(false, array('error' => 'Publication not found'));
        }
        if ((int) $publication->getData('status') === STATUS_PUBLISHED) {
            $existingSettings = $this->_loadDeclarationSettings($publicationId);
            $hasRealDeclaration = !empty($existingSettings['aiDeclaration_id'])
                || !empty($existingSettings['aiDeclaration_hash'])
                || !empty($existingSettings['aiDeclaration_url']);
            if ($hasRealDeclaration) {
                return new JSONMessage(false, array(
                    'error' => __('plugins.generic.aiDeclaration.workflow.errorPublished'),
                ));
            }
        }

        $newUrl  = trim((string) $request->getUserVar('aiDeclaration_url'));
        $newId   = trim((string) $request->getUserVar('aiDeclaration_id'));
        $newHash = trim((string) $request->getUserVar('aiDeclaration_hash'));
        $newUsed = $request->getUserVar('aiDeclaration_used');

        $data = array();
        if ($newUrl !== '')  $data['aiDeclaration_url']  = $newUrl;
        if ($newId !== '')   $data['aiDeclaration_id']   = $newId;
        if ($newHash !== '') $data['aiDeclaration_hash'] = $newHash;
        if (in_array((string) $newUsed, array('0', '1'), true)) {
            $data['aiDeclaration_used'] = (string) $newUsed;
        }

        // Validate declaration ID against the API (when an ID is being set)
        if (!empty($newId)) {
            $apiKey        = (string) $this->getSetting($context->getId(), 'apiKey');
            $declaradorUrl = (string) $this->getSetting($context->getId(), 'declaradorUrl');
            if (!empty($apiKey)) {
                import('plugins.generic.aiDeclaration.classes.DeclaradorApiClient');
                $langCode = $this->resolveLangCode($context->getPrimaryLocale());
                try {
                    $client    = new DeclaradorApiClient($declaradorUrl);
                    $apiResult = $client->getDeclaration($newId, $apiKey, $langCode);
                    // Authoritative hash always comes from the API
                    if (!empty($apiResult['validation_hash'])) {
                        $data['aiDeclaration_hash'] = (string) $apiResult['validation_hash'];
                    }
                    // Fill URL from API only if the editor did not supply one
                    if (empty($data['aiDeclaration_url']) && !empty($apiResult['declaration_url'])) {
                        $data['aiDeclaration_url'] = (string) $apiResult['declaration_url'];
                    }
                } catch (Exception $e) {
                    return new JSONMessage(false, array('error' => $e->getMessage()));
                }
            }
        }

        if (!empty($data)) {
            $this->_saveDeclarationSettings($publicationId, $data);
            // Clear the bypass flag when a real declaration (URL or ID) is registered
            if (!empty($newUrl) || !empty($newId)) {
                $publicationDao->update(
                    "DELETE FROM publication_settings WHERE publication_id = ? AND setting_name = 'aiDeclaration_bypass' AND locale = ''",
                    array($publicationId)
                );
            }
        }

        return new JSONMessage(true, array('success' => true));
    }

    // -------------------------------------------------------------------------
    // Helpers
    // -------------------------------------------------------------------------

    /**
     * Map OJS locale string (e.g. 'es_ES') to a two-letter API language code.
     */
    private function resolveLangCode(string $locale): string
    {
        $code = substr($locale, 0, 2);
        return in_array($code, array('es', 'en', 'pt', 'it')) ? $code : 'es';
    }

    /**
     * Persist declaration key/value pairs to publication_settings.
     * Uses DELETE + INSERT to avoid duplicates regardless of prior state.
     *
     * @param int   $publicationId
     * @param array $data  Associative array of setting_name => setting_value
     */
    private function _saveDeclarationSettings($publicationId, array $data)
    {
        $publicationDao = DAORegistry::getDAO('PublicationDAO');
        foreach ($data as $key => $value) {
            $publicationDao->update(
                "DELETE FROM publication_settings WHERE publication_id = ? AND setting_name = ? AND locale = ''",
                array((int) $publicationId, (string) $key)
            );
            $publicationDao->update(
                "INSERT INTO publication_settings (publication_id, locale, setting_name, setting_value) VALUES (?, '', ?, ?)",
                array((int) $publicationId, (string) $key, (string) $value)
            );
        }
    }

    /**
     * Load all aiDeclaration_* settings from publication_settings.
     *
     * @param int $publicationId
     * @return array  Associative array of setting_name => setting_value
     */
    private function _loadDeclarationSettings($publicationId)
    {
        $publicationDao = DAORegistry::getDAO('PublicationDAO');
        $result = $publicationDao->retrieve(
            "SELECT setting_name, setting_value FROM publication_settings WHERE publication_id = ? AND setting_name LIKE 'aiDeclaration_%' AND locale = ''",
            array((int) $publicationId)
        );
        $settings = array();
        foreach ($result as $row) {
            // retrieve() returns stdClass objects in OJS 3.3.x
            $row = (array) $row;
            $settings[$row['setting_name']] = $row['setting_value'];
        }
        return $settings;
    }
}
