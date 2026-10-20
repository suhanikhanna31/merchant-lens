package com.merchantlens.model;

import java.time.Instant;

/** Response DTO - only whitelisted fields are exposed (OWASP API3). */
public record DisputeResponse(
        String id,
        String merchantId,
        String status,
        Instant updatedAt) {
}
