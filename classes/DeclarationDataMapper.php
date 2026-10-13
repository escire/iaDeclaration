<?php
/**
 * Copyright 2026 eScire
 * Developed by eScire, with the collaboration of:
 *   - Gustavo Casiano Leon
 *   - Rebeca Maria Sirbu
 * Licensed under the Apache License, Version 2.0 (see LICENSE and NOTICE).
 */

/**
 * @file plugins/generic/aiDeclaration/classes/DeclarationDataMapper.php
 *
 * @class DeclarationDataMapper
 * @ingroup plugins_generic_aiDeclaration
 *
 * Maps OJS form POST data to the declarador.io API payload format.
 */

namespace APP\plugins\generic\aiDeclaration\classes;

use APP\facades\Repo;

class DeclarationDataMapper
{
    /**
     * Build the API payload from the POST request data and the current submission.
     *
     * @param array  $postData   Raw POST variables from the request
     * @param object $submission OJS Submission object
     * @param string $language   Two-letter language code: es, en, pt, it
     * @return array             Payload ready for DeclaradorApiClient::createDeclaration()
     */
    public function mapFromRequest(array $postData, $submission, string $language): array
    {
        $aiUsed = isset($postData['ai_used']) && $postData['ai_used'] === '1';

        $payload = [
            'ai_used'  => $aiUsed,
            'language' => $language,
        ];

        // Author data from the primary author of the submission
        $publication = $submission->getCurrentPublication();
        if ($publication) {
            $primaryAuthor = Repo::author()->getCollector()
                ->filterByPublicationIds([$publication->getId()])
                ->getMany()
                ->first();
            if ($primaryAuthor) {
                $authorName    = $primaryAuthor->getFullName();
                $authorEmail   = $primaryAuthor->getData('email');
                // OJS stores ORCID as a full URL; extract only the 19-char ID.
                $authorOrcid = preg_replace(
                    '/^https?:\/\/orcid\.org\//i',
                    '',
                    (string) $primaryAuthor->getData('orcid')
                );

                if (!empty($authorName))  $payload['author_name']  = $authorName;
                if (!empty($authorEmail)) $payload['author_email'] = $authorEmail;
                if (!empty($authorOrcid)) $payload['author_orcid'] = $authorOrcid;
            }
        }


        if (!$aiUsed) {
            return $payload;
        }

        // usage_types: free-form usage category checkboxes (draft, coauthor, etc.)
        $usageTypes = $postData['usage_types'] ?? [];
        if (is_array($usageTypes)) {
            $payload['usage_types'] = array_values(array_filter($usageTypes));
        }

        // selected_checklist_ids: diagnostic question IDs (q1–q7)
        $allowedIds   = ['q1', 'q2', 'q3', 'q4', 'q5', 'q6', 'q7'];
        $checklistIds = $postData['checklist_ids'] ?? [];
        if (is_array($checklistIds)) {
            $checklistIds = array_values(array_filter($checklistIds, function ($v) use ($allowedIds) {
                return in_array($v, $allowedIds, true);
            }));
        }
        if (!empty($checklistIds)) {
            $payload['selected_checklist_ids'] = $checklistIds;
        }

        // Custom usage type for "other"
        if (in_array('other', $payload['usage_types'] ?? [])) {
            $customUsage = trim((string) ($postData['custom_usage_type'] ?? ''));
            if (!empty($customUsage)) {
                $payload['custom_usage_type'] = $customUsage;
            }
        }

        // ai_tool
        $aiTool = [
            'name'       => trim((string) ($postData['ai_tool_name'] ?? '')),
            'date_month' => (int) ($postData['ai_tool_date_month'] ?? 0),
            'date_year'  => (int) ($postData['ai_tool_date_year'] ?? 0),
        ];
        $aiToolVersion = trim((string) ($postData['ai_tool_version'] ?? ''));
        if (!empty($aiToolVersion)) {
            $aiTool['version'] = $aiToolVersion;
        }
        $aiToolProvider = trim((string) ($postData['ai_tool_provider'] ?? ''));
        if (!empty($aiToolProvider)) {
            $aiTool['provider'] = $aiToolProvider;
        }
        $payload['ai_tool'] = $aiTool;

        // specific_purpose
        $payload['specific_purpose'] = trim((string) ($postData['specific_purpose'] ?? ''));

        // prompts: dynamic fields prompt_description[0], prompt_description[1], ...
        $promptDescriptions = $postData['prompt_description'] ?? [];
        $prompts = [];
        if (is_array($promptDescriptions)) {
            $index = 1;
            foreach ($promptDescriptions as $desc) {
                $desc = trim((string) $desc);
                if (!empty($desc)) {
                    $prompts[] = [
                        'id'          => (string) $index,
                        'description' => $desc,
                    ];
                    $index++;
                }
            }
        }
        $payload['prompts'] = $prompts;

        // content_use_modes: numeric IDs (0–5) as per API spec
        $contentUseModes = $postData['content_use_modes'] ?? [];
        if (is_array($contentUseModes) && !empty($contentUseModes)) {
            $contentUseModes = array_values(array_filter(array_map('intval', $contentUseModes), function ($v) {
                return $v >= 0;
            }));
            $payload['content_use_modes'] = $contentUseModes;

            // ID 5 = "Otro" — requires custom_content_use_mode
            if (in_array(5, $contentUseModes, true)) {
                $customMode = trim((string) ($postData['custom_content_use_mode'] ?? ''));
                if (!empty($customMode)) {
                    $payload['custom_content_use_mode'] = $customMode;
                }
            }
        }

        // content_use_context
        $contentUseContext = trim((string) ($postData['content_use_context'] ?? ''));
        if (!empty($contentUseContext)) {
            $payload['content_use_context'] = $contentUseContext;
        }

        // human_review
        $humanReviewLevel = isset($postData['human_review_level']) ? (int) $postData['human_review_level'] : 0;
        $humanReview = ['level' => $humanReviewLevel];
        $reviewerName = trim((string) ($postData['human_review_reviewer_name'] ?? ''));
        $reviewerRole = trim((string) ($postData['human_review_reviewer_role'] ?? ''));
        if (!empty($reviewerName)) $humanReview['reviewer_name'] = $reviewerName;
        if (!empty($reviewerRole)) $humanReview['reviewer_role'] = $reviewerRole;
        $payload['human_review'] = $humanReview;

        // license
        $license = trim((string) ($postData['license'] ?? ''));
        if (!empty($license) && $license !== 'None') {
            $payload['license'] = $license;
        }

        return $payload;
    }
}
