package com.escrow.mock.controller;

import com.escrow.mock.listener.QueueListener;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.amqp.rabbit.listener.RabbitListenerEndpointRegistry;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RestController;

@Slf4j
@RestController
@RequiredArgsConstructor
public class QueueController {

    private final RabbitListenerEndpointRegistry registry;

    @PostMapping("/api/resume")
    public ResponseEntity<String> resumeQueue() {
        log.info("Received request to resume the queue.");
        try {
            registry.getListenerContainer(QueueListener.LISTENER_ID).start();
            log.info("Queue listener successfully started.");
            return ResponseEntity.ok("Queue listener resumed.");
        } catch (Exception e) {
            log.error("Failed to start queue listener", e);
            return ResponseEntity.internalServerError().body("Failed to resume queue: " + e.getMessage());
        }
    }
}
