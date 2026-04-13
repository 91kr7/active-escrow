package com.escrow.mock.service;

import com.escrow.mock.model.BuildPayload;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

import java.util.HashMap;
import java.util.Map;

@Slf4j
@Service
@RequiredArgsConstructor
public class GitLabService {

    @Value("${escrow.provider.url}")
    private String providerUrl;

    @Value("${escrow.provider.token}")
    private String providerToken;
    
    @Value("${escrow.provider.projectId:provider-sync}")
    private String providerProjectId;

    private final RestTemplate restTemplate = new RestTemplate();
    private final ObjectMapper objectMapper = new ObjectMapper();

    public void triggerProviderPipelineAndWait(BuildPayload payload) throws Exception {
        log.info("Triggering Provider Pipeline {} for path: {} and commit: {}", providerProjectId, payload.getRelativePath(), payload.getCommitHash());

        String projectNameEncoded = providerProjectId.replace("/", "%2F");
        String projectApiUrl = providerUrl + "/api/v4/projects/" + projectNameEncoded;
        String triggerUrl = projectApiUrl + "/pipeline";

        HttpHeaders headers = new HttpHeaders();
        headers.set("PRIVATE-TOKEN", providerToken);

        Map<String, Object> requestBody = new HashMap<>();
        requestBody.put("ref", "main"); // We assume the provider sync pipeline is on main branch
        
        Map<String, String> vars = payload.getBuildVariables() != null ? payload.getBuildVariables() : new HashMap<>();
        vars.put("PAYLOAD_SOURCE_PATH", payload.getRelativePath());
        vars.put("PAYLOAD_SOURCE_BRANCH", payload.getBranch());
        vars.put("PAYLOAD_COMMIT_HASH", payload.getCommitHash());

        Object[] formattedVars = vars.entrySet().stream()
                .map(e -> {
                    Map<String, String> m = new HashMap<>();
                    m.put("key", e.getKey());
                    m.put("value", e.getValue());
                    return m;
                }).toArray();

        requestBody.put("variables", formattedVars);

        HttpEntity<Map<String, Object>> entity = new HttpEntity<>(requestBody, headers);

        int pipelineId;
        try {
            ResponseEntity<String> response = restTemplate.exchange(triggerUrl, HttpMethod.POST, entity, String.class);
            JsonNode root = objectMapper.readTree(response.getBody());
            pipelineId = root.get("id").asInt();
            log.info("Provider Pipeline triggered successfully. Pipeline ID: {}", pipelineId);
        } catch (Exception e) {
            log.error("Failed to trigger Provider Pipeline: {}", e.getMessage());
            throw new Exception("Provider Pipeline Trigger Failed", e);
        }

        waitForPipeline(projectApiUrl, pipelineId, headers);
    }

    private void waitForPipeline(String projectApiUrl, int pipelineId, HttpHeaders headers) throws Exception {
        String statusUrl = projectApiUrl + "/pipelines/" + pipelineId;
        HttpEntity<Void> entity = new HttpEntity<>(headers);

        while (true) {
            try {
                Thread.sleep(5000); // poll every 5 seconds
                ResponseEntity<String> response = restTemplate.exchange(statusUrl, HttpMethod.GET, entity, String.class);
                JsonNode root = objectMapper.readTree(response.getBody());
                String status = root.get("status").asText();
                
                log.info("Provider Pipeline {} status: {}", pipelineId, status);
                
                if ("success".equalsIgnoreCase(status)) {
                    log.info("Provider Pipeline finished successfully.");
                    break;
                } else if ("failed".equalsIgnoreCase(status) || "canceled".equalsIgnoreCase(status)) {
                    String webUrl = root.has("web_url") ? root.get("web_url").asText() : "N/A";
                    log.error("Provider Pipeline ended with status: {}. Pipeline URL: {}", status, webUrl);
                    throw new Exception("Provider Pipeline did not succeed. Status: " + status);
                }
                // running, pending, created, waiting_for_resource -> keep polling
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
                throw new Exception("Polling interrupted", e);
            }
        }
    }
}
