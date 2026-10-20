package com.merchantlens.service;

import com.merchantlens.model.DisputeResponse;

import java.util.List;
import java.util.Optional;

/** Contract used by DisputeController. TODO: add the JDBC/JPA implementation. */
public interface DisputeService {

    List<DisputeResponse> findDisputes(String updatedSince, String merchantId, String status);

    Optional<DisputeResponse> findById(String id);

    DisputeResponse escalate(String id);

    List<?> getChargebackRatioSummary();
}
