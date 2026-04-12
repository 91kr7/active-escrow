package com.escrow.mock.model;

import lombok.Data;
import java.util.Map;

@Data
public class BuildPayload {
    private String relativePath;
    private String branch;
    private String commitHash;
    private Map<String, String> buildVariables;
}
