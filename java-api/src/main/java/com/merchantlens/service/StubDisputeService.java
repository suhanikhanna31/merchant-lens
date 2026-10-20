package com.merchantlens.service;

import com.merchantlens.model.DisputeResponse;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

import java.util.List;
import java.util.Optional;

/**
 * Placeholder implementation so the application context can start (and be
 * scanned by DAST) before the real JDBC/JPA-backed service exists.
 *
 * TODO: replace with a database-backed implementation and delete this class.
 * Read endpoints return empty results; escalate() answers 501 Not Implemented.
 */
@Service
public class StubDisputeService implements DisputeService {

    @Override
    public List<DisputeResponse> findDisputes(String updatedSince, String merchantId, String status) {
        return List.of();
    }

    @Override
    public Optional<DisputeResponse> findById(String id) {
        return Optional.empty();
    }

    @Override
    public DisputeResponse escalate(String id) {
        throw new ResponseStatusException(HttpStatus.NOT_IMPLEMENTED, "Dispute escalation is not implemented yet");
    }

    @Override
    public List<?> getChargebackRatioSummary() {
        return List.of();
    }
}
