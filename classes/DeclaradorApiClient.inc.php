<?php
/**
 * Copyright 2026 eScire
 * Developed by eScire, with the collaboration of:
 *   - Gustavo Casiano Leon
 * Licensed under the Apache License, Version 2.0 (see LICENSE and NOTICE).
 */

/**
 * @file plugins/generic/aiDeclaration/classes/DeclaradorApiClient.inc.php
 *
 * @class DeclaradorApiClient
 * @ingroup plugins_generic_aiDeclaration
 *
 * HTTP client for the declarador API v1.
 * The base URL is configurable to support self-hosted / decentralized instances.
 */

class DeclaradorApiClient
{
    const API_ENDPOINT     = '/api/v1/declaracion/';
    const OPTIONS_ENDPOINT = '/api/v1/opciones/';
    const DEFAULT_BASE_URL = 'https://declarador.usoeticoia.org/';
    const TIMEOUT_SECONDS  = 30;

    /** @var string Base URL of the declarador instance (no trailing slash) */
    private $baseUrl;

    /**
     * @param string $baseUrl  Base URL of the declarador instance.
     *                         Defaults to https://declarador.usoeticoia.org/ if empty.
     */
    public function __construct(string $baseUrl = '')
    {
        $this->baseUrl = rtrim(
            empty($baseUrl) ? self::DEFAULT_BASE_URL : $baseUrl,
            '/'
        );
    }

    /**
     * Test connectivity and authentication against the declarador API.
     *
     * Strategy: attempt a GET for a deliberately invalid ID ("TEST0000").
     * - 404 → server is reachable and API responded (auth OK or not needed for this)
     * - 401 → server reachable but API key is wrong
     * - 200 with success → server reachable (unlikely for TEST0000 but handled)
     * - cURL error → DNS / network / SSL issue
     *
     * Returns an array:
     *   [ 'ok' => bool, 'httpCode' => int|null, 'error' => string, 'url' => string ]
     *
     * @param string $apiKey  Bearer token
     * @return array
     */
    public function ping(string $apiKey): array
    {
        $url = $this->baseUrl . self::API_ENDPOINT . '12770F510E972A32/';

        $verboseLog = fopen('php://temp', 'w+');

        $ch = curl_init($url);
        curl_setopt_array($ch, array(
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_HTTPGET        => true,
            CURLOPT_HTTPHEADER     => array(
                'Authorization: Bearer ' . $apiKey,
                'Accept: application/json',
            ),
            CURLOPT_TIMEOUT        => 10,
            CURLOPT_SSL_VERIFYPEER => true,
            CURLOPT_VERBOSE        => true,
            CURLOPT_STDERR         => $verboseLog,
        ));

        $response  = curl_exec($ch);
        $httpCode  = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        $curlError = curl_error($ch);
        $curlErrNo = curl_errno($ch);
        curl_close($ch);

        rewind($verboseLog);
        $verboseOutput = stream_get_contents($verboseLog);
        fclose($verboseLog);

        // Log full debug trace to PHP error log
        error_log('[aiDeclaration] ping URL: ' . $url);
        error_log('[aiDeclaration] ping HTTP code: ' . $httpCode);
        if (!empty($curlError)) {
            error_log('[aiDeclaration] ping cURL error (' . $curlErrNo . '): ' . $curlError);
        }
        error_log('[aiDeclaration] ping verbose: ' . $verboseOutput);

        if (!empty($curlError)) {
            return array(
                'ok'       => false,
                'httpCode' => null,
                'error'    => 'cURL error (' . $curlErrNo . '): ' . $curlError,
                'url'      => $url,
            );
        }

        // 404 means server is reachable and API is responding correctly
        if ($httpCode === 404 || $httpCode === 200) {
            return array(
                'ok'       => true,
                'httpCode' => $httpCode,
                'error'    => '',
                'url'      => $url,
            );
        }

        if ($httpCode === 401) {
            return array(
                'ok'       => false,
                'httpCode' => 401,
                'error'    => 'API key inválida o inactiva (401) — el servidor SÍ responde',
                'url'      => $url,
            );
        }

        $decoded = json_decode($response, true);
        $detail  = isset($decoded['error']) ? $decoded['error'] : ($response ? substr($response, 0, 200) : 'sin respuesta');

        return array(
            'ok'       => false,
            'httpCode' => $httpCode,
            'error'    => 'HTTP ' . $httpCode . ': ' . $detail,
            'url'      => $url,
        );
    }

    /**
     * Retrieve an existing declaration from the declarador API.
     *
     * @param string $identifier  declaration_id (8 chars) or validation_hash (16 chars)
     * @param string $apiKey      Bearer token
     * @param string $lang        Language code: es, en, pt, it
     * @return array              API response
     * @throws Exception          On HTTP errors or cURL failures
     */
    public function getDeclaration(string $identifier, string $apiKey, string $lang = 'es'): array
    {
        $url = $this->baseUrl . self::API_ENDPOINT . rawurlencode($identifier) . '/';
        if (!empty($lang)) {
            $url .= '?lang=' . urlencode($lang);
        }

        $ch = curl_init($url);
        curl_setopt_array($ch, array(
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_HTTPGET        => true,
            CURLOPT_HTTPHEADER     => array(
                'Authorization: Bearer ' . $apiKey,
                'Accept: application/json',
            ),
            CURLOPT_TIMEOUT        => self::TIMEOUT_SECONDS,
            CURLOPT_SSL_VERIFYPEER => true,
        ));

        $response  = curl_exec($ch);
        $httpCode  = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        $curlError = curl_error($ch);
        curl_close($ch);

        if ($response === false || !empty($curlError)) {
            throw new Exception('Declarador API cURL error (GET): ' . $curlError);
        }

        $decoded = json_decode($response, true);

        if ($httpCode === 401) {
            throw new Exception('Declarador API: API key inválida o inactiva (401)');
        }
        if ($httpCode === 404 || $httpCode === 400) {
            $detail = isset($decoded['error']) ? $decoded['error'] : 'declaración no encontrada';
            throw new Exception($detail);
        }
        if ($httpCode !== 200) {
            throw new Exception('Declarador API: error del servidor HTTP ' . $httpCode);
        }
        if (!isset($decoded['success']) || $decoded['success'] !== true) {
            throw new Exception('Declarador API GET: ' . ($decoded['error'] ?? 'Unknown error'));
        }

        return $decoded;
    }

    /**
     * Create a new declaration via the declarador API.
     *
     * @param array  $data   Payload as per API_INTEGRACION.md
     * @param string $apiKey Bearer token
     * @return array         API response (success, declaration_id, validation_hash, declaration_url, …)
     * @throws Exception     On HTTP errors or cURL failures
     */
    public function createDeclaration(array $data, string $apiKey): array
    {
        $url     = $this->baseUrl . self::API_ENDPOINT;
        $payload = json_encode($data);

        $ch = curl_init($url);
        curl_setopt_array($ch, array(
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_POST           => true,
            CURLOPT_POSTFIELDS     => $payload,
            CURLOPT_HTTPHEADER     => array(
                'Authorization: Bearer ' . $apiKey,
                'Content-Type: application/json',
                'Accept: application/json',
            ),
            CURLOPT_TIMEOUT        => self::TIMEOUT_SECONDS,
            CURLOPT_SSL_VERIFYPEER => true,
        ));

        $response  = curl_exec($ch);
        $httpCode  = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        $curlError = curl_error($ch);
        curl_close($ch);

        if ($response === false || !empty($curlError)) {
            throw new Exception('Declarador API cURL error: ' . $curlError);
        }

        $decoded = json_decode($response, true);

        if ($httpCode === 401) {
            throw new Exception('Declarador API: API key inválida o inactiva (401)');
        }
        if ($httpCode === 400) {
            $errors = isset($decoded['errors']) ? implode('; ', $decoded['errors']) : 'Bad request';
            throw new Exception('Declarador API: error de validación (400): ' . $errors);
        }
        if ($httpCode !== 200) {
            throw new Exception('Declarador API: error del servidor HTTP ' . $httpCode);
        }
        if (!isset($decoded['success']) || $decoded['success'] !== true) {
            throw new Exception('Declarador API: ' . ($decoded['error'] ?? 'Unknown error'));
        }

        return $decoded;
    }

    /**
     * Retrieve available options (usage_types, content_use_modes, human_review_levels,
     * checklist) from the declarador API.
     *
     * @param string $apiKey  Bearer token
     * @param string $lang    Language code: es, en, pt, it
     * @return array          API response with option lists
     * @throws Exception      On HTTP errors or cURL failures
     */
    public function getOptions(string $apiKey, string $lang = 'es'): array
    {
        $url = $this->baseUrl . self::OPTIONS_ENDPOINT . '?lang=' . urlencode($lang);

        $ch = curl_init($url);
        curl_setopt_array($ch, array(
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_HTTPGET        => true,
            CURLOPT_HTTPHEADER     => array(
                'Authorization: Bearer ' . $apiKey,
                'Accept: application/json',
            ),
            CURLOPT_TIMEOUT        => 10,
            CURLOPT_SSL_VERIFYPEER => true,
        ));

        $response  = curl_exec($ch);
        $httpCode  = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        $curlError = curl_error($ch);
        curl_close($ch);

        if ($response === false || !empty($curlError)) {
            throw new Exception('Declarador API getOptions cURL error: ' . $curlError);
        }
        if ($httpCode !== 200) {
            throw new Exception('Declarador API getOptions: HTTP ' . $httpCode);
        }

        $decoded = json_decode($response, true);
        if (!isset($decoded['success']) || $decoded['success'] !== true) {
            throw new Exception('Declarador API getOptions: ' . ($decoded['error'] ?? 'Unknown error'));
        }

        return $decoded;
    }
}
