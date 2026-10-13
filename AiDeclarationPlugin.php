<?php
/**
 * Copyright 2026 eScire
 * Developed by eScire, with the collaboration of:
 *   - Gustavo Casiano Leon
 *   - Rebeca Maria Sirbu
 * Licensed under the Apache License, Version 2.0 (see LICENSE and NOTICE).
 */
namespace APP\plugins\generic\aiDeclaration;

use APP\core\Application;
use APP\facades\Repo;
use APP\plugins\generic\aiDeclaration\classes\DeclaradorApiClient;
use APP\plugins\generic\aiDeclaration\classes\DeclarationDataMapper;
use APP\plugins\generic\aiDeclaration\form\AiDeclarationSettingsForm;
use Exception;
use Illuminate\Support\Facades\DB;
use PKP\core\JSONMessage;
use PKP\db\DAORegistry;
use PKP\facades\Locale;
use PKP\linkAction\LinkAction;
use PKP\linkAction\request\AjaxModal;
use PKP\plugins\GenericPlugin;
use PKP\plugins\Hook;
use PKP\security\Role;
use PKP\submission\PKPSubmission;
use PKP\template\PKPTemplateManager;

class AiDeclarationPlugin extends GenericPlugin
{
    public function register($category, $path, $mainContextId = NULL)
    {
        $success = parent::register($category, $path);

        if ($success && $this->getEnabled()) {
            // Fires before rendering — safe moment to enqueue CSS + JS and inject
            // the aiDeclaration step into the wizard state.
            Hook::add('TemplateManager::display', [$this, 'addWizardAssets']);
            Hook::add('LoadComponentHandler', [$this, 'setupComponentHandler']);
            Hook::add('TemplateResource::getFilename', [$this, '_overridePluginTemplates']);
            Hook::add('Template::Workflow::Publication', [$this, 'addDeclarationTabToWorkflow']);
            Hook::add('Templates::Article::Details', [$this, 'addDeclarationToArticle']);
        }

        return $success;
    }

    public function getDisplayName()
    {
        return __('plugins.generic.aiDeclaration.displayName');
    }

    public function getDescription()
    {
        return __('plugins.generic.aiDeclaration.description');
    }

    // -------------------------------------------------------------------------
    // Hook: enqueue CSS + JS for the submission wizard (fires before rendering)
    // -------------------------------------------------------------------------

    /**
     * Hook: TemplateManager::display
     * params: [templateMgr, &$template, &$output]
     * Fires before Smarty renders — safe window to call addStyleSheet/addJavaScript.
     */
    public function addWizardAssets($hookName, $params)
    {
        $template = $params[1];
        if ($template !== 'submission/wizard.tpl') {
            return false;
        }

        $request     = Application::get()->getRequest();
        $context     = $request->getContext();
        $contextId   = $context ? $context->getId() : 0;
        $pluginUrl   = $request->getBaseUrl() . '/' . $this->getPluginPath();
        $templateMgr = PKPTemplateManager::getManager($request);

        // --- CSS & JS assets ---
        $templateMgr->addStyleSheet(
            'aiDeclarationWizard',
            $pluginUrl . '/assets/css/aiDeclaration.css',
            ['contexts' => 'backend', 'priority' => PKPTemplateManager::STYLE_SEQUENCE_LATE]
        );
        $templateMgr->addJavaScript(
            'aiDeclarationWizard',
            $pluginUrl . '/assets/js/declarationWizard.js',
            ['contexts' => 'backend', 'priority' => PKPTemplateManager::STYLE_SEQUENCE_LATE]
        );

        // --- Inject aiDeclaration step into Vue wizard state (before 'confirm') ---
        // getState() works here because PKPSubmissionHandler calls setState() BEFORE display().
        $steps = $templateMgr->getState('steps');
        if (is_array($steps)) {
            $insertAt = count($steps);
            foreach ($steps as $i => $step) {
                if (($step['id'] ?? '') === 'confirm') {
                    $insertAt = $i;
                    break;
                }
            }
            array_splice($steps, $insertAt, 0, [[
                'id'             => 'aiDeclaration',
                'name'           => __('plugins.generic.aiDeclaration.step.name'),
                'reviewName'     => __('plugins.generic.aiDeclaration.step.name'),
                'sections'       => [],   // Empty — JS injects the form HTML
                'reviewTemplate' => null,
                'isComplete'     => false,
                'errors'         => [],
                'skipped'        => false,
            ]]);
            $templateMgr->setState(['steps' => $steps]);
        }

        // --- Pre-render declaration form and expose to JS as window.aiDeclarationFormHTML ---
        $submissionId     = (int) $request->getUserVar('id');
        $submission       = $submissionId ? Repo::submission()->get($submissionId) : null;
        $currentYear      = (int) date('Y');
        $existingSettings = [];

        if ($submission && $submission->getCurrentPublication()) {
            $existingSettings = $this->_loadDeclarationSettings(
                $submission->getCurrentPublication()->getId()
            );
        }

        $handlerComponent = str_replace('/', '.', $this->getPluginPath())
            . '.classes.AiDeclarationHandler';

        $apiOptions    = [];
        $apiKey        = (string) $this->getSetting($contextId, 'apiKey');
        $declaradorUrl = (string) $this->getSetting($contextId, 'declaradorUrl');
        if (!empty($apiKey)) {
            try {
                $client     = new \APP\plugins\generic\aiDeclaration\classes\DeclaradorApiClient($declaradorUrl);
                $apiOptions = $client->getOptions($apiKey, $this->resolveLangCode(Locale::getLocale()));
            } catch (Exception $e) {
                error_log('[aiDeclaration] getOptions in addWizardAssets failed: ' . $e->getMessage());
            }
        }

        $templateMgr->assign([
            'aiDeclarationRequired'     => (bool) $this->getSetting($contextId, 'requireDeclaration'),
            'aiDeclarationYears'        => range($currentYear, 2020),
            'aiDeclarationPluginUrl'    => $pluginUrl,
            'aiDeclarationPluginName'   => $this->getName(),
            'aiDeclarationComponent'    => $handlerComponent,
            'aiDeclarationSubmissionId' => $submission ? $submission->getId() : 0,
            'aiDeclarationExisting'     => $existingSettings,
            'aiDeclarationOptions'      => $apiOptions,
        ]);

        $formHtml = $templateMgr->fetch($this->getTemplateResource('declarationForm.tpl'));
        $required = (bool) $this->getSetting($contextId, 'requireDeclaration');

        $inlineJs  = 'window.aiDeclarationFormHTML = ' . json_encode($formHtml) . ';';
        $inlineJs .= 'window.aiDeclarationRequired = ' . ($required ? 'true' : 'false') . ';';
        $templateMgr->addJavaScript('aiDeclarationData', $inlineJs, [
            'inline'   => true,
            'contexts' => 'backend',
            'priority' => PKPTemplateManager::STYLE_SEQUENCE_LATE,
        ]);

        return false;
    }

    // -------------------------------------------------------------------------
    // Hook: intercept component handler for AJAX requests
    // -------------------------------------------------------------------------

    public function setupComponentHandler($hookName, $params)
    {
        $component = $params[0];
        $componentInstance = &$params[2];
        $expectedComponent = str_replace('/', '.', $this->getPluginPath())
            . '.classes.AiDeclarationHandler';
        if ($component === $expectedComponent) {
            $componentInstance = new \APP\plugins\generic\aiDeclaration\classes\AiDeclarationHandler();
            return true;
        }
        return false;
    }

    // -------------------------------------------------------------------------
    // Hook: inject declaration form into the wizard review step (Details section)
    // -------------------------------------------------------------------------

    /**
     * Hook: Template::SubmissionWizard::Section::Review::Details
     *
     * $args[0] = Smarty params array (has 'submission', 'step')
     * $args[1] = Smarty_Internal_Template (NOT PKPTemplateManager)
     * $args[2] = &$output string — append HTML here
     */
    public function addDeclarationFormToWizard($hookName, $args)
    {
        $output     = &$args[2];
        $submission = $args[0]['submission'] ?? null;

        $request   = Application::get()->getRequest();
        $contextId = $request->getContext()->getId();

        $currentYear = (int) date('Y');
        $pluginUrl   = $request->getBaseUrl() . '/' . $this->getPluginPath();

        // Pre-load existing declaration settings (when author returns to the wizard)
        $existingSettings = [];
        if ($submission) {
            $pub = $submission->getCurrentPublication();
            if ($pub) {
                $existingSettings = $this->_loadDeclarationSettings($pub->getId());
            }
        }

        // Component path for AiDeclarationHandler AJAX routing
        $handlerComponent = str_replace('/', '.', $this->getPluginPath())
            . '.classes.AiDeclarationHandler';

        // Fetch available options from the API
        $apiOptions    = [];
        $apiKey        = (string) $this->getSetting($contextId, 'apiKey');
        $declaradorUrl = (string) $this->getSetting($contextId, 'declaradorUrl');
        $langCode      = $this->resolveLangCode(Locale::getLocale());
        if (!empty($apiKey)) {
            try {
                $client     = new DeclaradorApiClient($declaradorUrl);
                $apiOptions = $client->getOptions($apiKey, $langCode);
            } catch (Exception $e) {
                error_log('[aiDeclaration] getOptions failed: ' . $e->getMessage());
            }
        }

        // Use the PKPTemplateManager singleton to assign variables and fetch the sub-template
        $templateMgr = PKPTemplateManager::getManager($request);
        $templateMgr->assign([
            'aiDeclarationRequired'     => (bool) $this->getSetting($contextId, 'requireDeclaration'),
            'aiDeclarationYears'        => range($currentYear, 2020),
            'aiDeclarationPluginUrl'    => $pluginUrl,
            'aiDeclarationPluginName'   => $this->getName(),
            'aiDeclarationComponent'    => $handlerComponent,
            'aiDeclarationSubmissionId' => $submission ? $submission->getId() : 0,
            'aiDeclarationExisting'     => $existingSettings,
            'aiDeclarationOptions'      => $apiOptions,
        ]);

        $output .= $templateMgr->fetch($this->getTemplateResource('declarationForm.tpl'));
        return false;
    }

    // -------------------------------------------------------------------------
    // Hook: show declaration badge in published article detail page
    // -------------------------------------------------------------------------

    /**
     * Hook: Templates::Article::Details
     * params: [hookName, &$smarty, &$output]
     */
    public function addDeclarationToArticle($hookName, $params)
    {
        $smarty = &$params[1];
        $output = &$params[2];

        $submission = $smarty->getTemplateVars('article');
        if (!$submission) {
            return false;
        }

        $publication = $submission->getCurrentPublication();
        if (!$publication) {
            return false;
        }

        $settings = $this->_loadDeclarationSettings($publication->getId());
        $aiUsed   = $settings['aiDeclaration_used'] ?? null;
        if ($aiUsed === null) {
            return false;
        }

        $request   = Application::get()->getRequest();
        $pluginUrl = $request->getBaseUrl() . '/' . $this->getPluginPath();
        $templateMgr = PKPTemplateManager::getManager($request);
        $templateMgr->addStyleSheet(
            'aiDeclarationFrontend',
            $pluginUrl . '/assets/css/aiDeclaration.css',
            ['contexts' => 'frontend', 'priority' => PKPTemplateManager::STYLE_SEQUENCE_LATE]
        );

        $smarty->assign([
            'aiDeclaration_used'  => (bool) $aiUsed,
            'aiDeclaration_id'    => $settings['aiDeclaration_id']   ?? '',
            'aiDeclaration_hash'  => $settings['aiDeclaration_hash'] ?? '',
            'aiDeclaration_url'   => $settings['aiDeclaration_url']  ?? '',
        ]);

        $output .= $smarty->fetch($this->getTemplateResource('articleDeclaration.tpl'));
        return false;
    }

    // -------------------------------------------------------------------------
    // Hook: add "Declaración IA" tab to the Publication panel in workflow
    // -------------------------------------------------------------------------

    /**
     * Hook: Template::Workflow::Publication
     * params: [&$smarty, &$output]
     */
    public function addDeclarationTabToWorkflow($hookName, $params)
    {
        $smarty = &$params[1];
        $output = &$params[2];

        $submission = $smarty->getTemplateVars('submission');
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

        $smarty->assign([
            'aiDeclarationWorkflow'                   => $settings,
            'aiDeclarationWorkflowPubId'              => $publication->getId(),
            'aiDeclarationWorkflowIsPublished'        => ((int) $publication->getData('status') === PKPSubmission::STATUS_PUBLISHED),
            'aiDeclarationWorkflowHasRealDeclaration' => $hasRealDeclaration,
            'aiDeclarationComponent'                  => $handlerComponent,
        ]);

        $output .= $smarty->fetch($this->getTemplateResource('workflowDeclaration.tpl'));
        return false;
    }

    // -------------------------------------------------------------------------
    // Settings / Plugin management
    // -------------------------------------------------------------------------

    public function getActions($request, $actionArgs)
    {
        $router = $request->getRouter();
        return array_merge(
            $this->getEnabled() ? [
                new LinkAction(
                    'settings',
                    new AjaxModal(
                        $router->url(
                            $request,
                            null,
                            null,
                            'manage',
                            null,
                            [
                                'verb'     => 'settings',
                                'plugin'   => $this->getName(),
                                'category' => 'generic',
                            ]
                        ),
                        $this->getDisplayName()
                    ),
                    __('manager.plugins.settings'),
                    null
                ),
            ] : [],
            parent::getActions($request, $actionArgs)
        );
    }

    public function manage($args, $request)
    {
        switch ($request->getUserVar('verb')) {

            case 'settings':
                $context = $request->getContext();
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

    private function _handleAjaxCreate($request)
    {
        $context       = $request->getContext();
        $apiKey        = (string) $this->getSetting($context->getId(), 'apiKey');
        $declaradorUrl = (string) $this->getSetting($context->getId(), 'declaradorUrl');
        $langCode      = $this->resolveLangCode($context->getPrimaryLocale());

        if (empty($apiKey)) {
            return new JSONMessage(false, [
                'error' => __('plugins.generic.aiDeclaration.error.noApiKey'),
            ]);
        }

        $submissionId = (int) $request->getUserVar('submissionId');
        $submission   = Repo::submission()->get($submissionId);

        if (!$submission) {
            return new JSONMessage(false, ['error' => 'Submission not found']);
        }

        try {
            $mapper  = new DeclarationDataMapper();
            $payload = $mapper->mapFromRequest($request->getUserVars(), $submission, $langCode);

            $client = new DeclaradorApiClient($declaradorUrl);
            $result = $client->createDeclaration($payload, $apiKey);

            if (!empty($result['success']) && !empty($result['declaration_id'])) {
                $aiUsed      = ($request->getUserVar('ai_used') === '0') ? '0' : '1';
                $publication = $submission->getCurrentPublication();
                if ($publication) {
                    $this->_saveDeclarationSettings($publication->getId(), [
                        'aiDeclaration_used' => $aiUsed,
                        'aiDeclaration_id'   => (string) $result['declaration_id'],
                        'aiDeclaration_hash' => (string) ($result['validation_hash'] ?? ''),
                        'aiDeclaration_url'  => (string) ($result['declaration_url']  ?? ''),
                    ]);
                }
            }

            return new JSONMessage(true, $result);
        } catch (Exception $e) {
            error_log('[aiDeclaration] ajaxCreate error: ' . $e->getMessage());
            return new JSONMessage(false, ['error' => $e->getMessage()]);
        }
    }

    private function _handleAjaxFind($request)
    {
        $context       = $request->getContext();
        $apiKey        = (string) $this->getSetting($context->getId(), 'apiKey');
        $declaradorUrl = (string) $this->getSetting($context->getId(), 'declaradorUrl');
        $langCode      = $this->resolveLangCode($context->getPrimaryLocale());

        $identifier = trim((string) $request->getUserVar('existing_declaration_id'));
        if (empty($identifier)) {
            return new JSONMessage(false, [
                'error' => __('plugins.generic.aiDeclaration.error.existingDeclarationIdRequired'),
            ]);
        }

        if (empty($apiKey)) {
            return new JSONMessage(false, [
                'error' => __('plugins.generic.aiDeclaration.error.noApiKey'),
            ]);
        }

        try {
            $client = new DeclaradorApiClient($declaradorUrl);
            $result = $client->getDeclaration($identifier, $apiKey, $langCode);
            return new JSONMessage(true, $result);
        } catch (Exception $e) {
            error_log('[aiDeclaration] ajaxFind error: ' . $e->getMessage());
            return new JSONMessage(false, ['error' => $e->getMessage()]);
        }
    }

    private function _handleAjaxUpdateMeta($request)
    {
        if (!$request->checkCSRF()) {
            return new JSONMessage(false, ['error' => 'Invalid CSRF token']);
        }

        $user    = $request->getUser();
        $context = $request->getContext();
        if (!$user || !$context) {
            return new JSONMessage(false, ['error' => 'Not authenticated']);
        }
        $roleDao = DAORegistry::getDAO('RoleDAO');
        if (!$roleDao->userHasRole($context->getId(), $user->getId(), Role::ROLE_ID_MANAGER) &&
            !$roleDao->userHasRole($context->getId(), $user->getId(), Role::ROLE_ID_SUB_EDITOR)) {
            return new JSONMessage(false, ['error' => 'Access denied']);
        }

        $publicationId = (int) $request->getUserVar('publicationId');
        if (!$publicationId) {
            return new JSONMessage(false, ['error' => 'Publication ID required']);
        }

        $publication = Repo::publication()->get($publicationId);
        if (!$publication) {
            return new JSONMessage(false, ['error' => 'Publication not found']);
        }

        if ((int) $publication->getData('status') === PKPSubmission::STATUS_PUBLISHED) {
            $existingSettings   = $this->_loadDeclarationSettings($publicationId);
            $hasRealDeclaration = !empty($existingSettings['aiDeclaration_id'])
                || !empty($existingSettings['aiDeclaration_hash'])
                || !empty($existingSettings['aiDeclaration_url']);
            if ($hasRealDeclaration) {
                return new JSONMessage(false, [
                    'error' => __('plugins.generic.aiDeclaration.workflow.errorPublished'),
                ]);
            }
        }

        $newUrl  = trim((string) $request->getUserVar('aiDeclaration_url'));
        $newId   = trim((string) $request->getUserVar('aiDeclaration_id'));
        $newHash = trim((string) $request->getUserVar('aiDeclaration_hash'));
        $newUsed = $request->getUserVar('aiDeclaration_used');

        $data = [];
        if ($newUrl !== '')  $data['aiDeclaration_url']  = $newUrl;
        if ($newId !== '')   $data['aiDeclaration_id']   = $newId;
        if ($newHash !== '') $data['aiDeclaration_hash'] = $newHash;
        if (in_array((string) $newUsed, ['0', '1'], true)) {
            $data['aiDeclaration_used'] = (string) $newUsed;
        }

        if (!empty($newId)) {
            $apiKey        = (string) $this->getSetting($context->getId(), 'apiKey');
            $declaradorUrl = (string) $this->getSetting($context->getId(), 'declaradorUrl');
            if (!empty($apiKey)) {
                $langCode = $this->resolveLangCode($context->getPrimaryLocale());
                try {
                    $client    = new DeclaradorApiClient($declaradorUrl);
                    $apiResult = $client->getDeclaration($newId, $apiKey, $langCode);
                    if (!empty($apiResult['validation_hash'])) {
                        $data['aiDeclaration_hash'] = (string) $apiResult['validation_hash'];
                    }
                    if (empty($data['aiDeclaration_url']) && !empty($apiResult['declaration_url'])) {
                        $data['aiDeclaration_url'] = (string) $apiResult['declaration_url'];
                    }
                } catch (Exception $e) {
                    return new JSONMessage(false, ['error' => $e->getMessage()]);
                }
            }
        }

        if (!empty($data)) {
            $this->_saveDeclarationSettings($publicationId, $data);
            if (!empty($newUrl) || !empty($newId)) {
                DB::statement(
                    "DELETE FROM publication_settings WHERE publication_id = ? AND setting_name = 'aiDeclaration_bypass' AND locale = ''",
                    [$publicationId]
                );
            }
        }

        return new JSONMessage(true, ['success' => true]);
    }

    // -------------------------------------------------------------------------
    // Helpers
    // -------------------------------------------------------------------------

    private function resolveLangCode(string $locale): string
    {
        $code = substr($locale, 0, 2);
        return in_array($code, ['es', 'en', 'pt', 'it']) ? $code : 'es';
    }

    private function _saveDeclarationSettings(int $publicationId, array $data): void
    {
        foreach ($data as $key => $value) {
            DB::statement(
                "DELETE FROM publication_settings WHERE publication_id = ? AND setting_name = ? AND locale = ''",
                [$publicationId, (string) $key]
            );
            DB::statement(
                "INSERT INTO publication_settings (publication_id, locale, setting_name, setting_value) VALUES (?, '', ?, ?)",
                [$publicationId, (string) $key, (string) $value]
            );
        }
    }

    private function _loadDeclarationSettings(int $publicationId): array
    {
        $rows = DB::select(
            "SELECT setting_name, setting_value FROM publication_settings WHERE publication_id = ? AND setting_name LIKE 'aiDeclaration_%' AND locale = ''",
            [$publicationId]
        );
        $settings = [];
        foreach ($rows as $row) {
            $settings[$row->setting_name] = $row->setting_value;
        }
        return $settings;
    }
}
